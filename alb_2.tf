################################################################################
# Cluster 2: public load balancer in front of backend-2
################################################################################

locals {
  backend_2_https_enabled = var.backend_2_certificate_arn != null

  # Public address of backend-2, called over the internet by the backend in cluster 1
  backend_2_url = "${local.backend_2_https_enabled ? "https" : "http"}://${aws_lb.backend_2.dns_name}"
}

resource "aws_lb" "backend_2" {
  name               = "${local.name_prefix_2}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_2_alb.id]
  subnets            = module.vpc_2.public_subnet_ids

  drop_invalid_header_fields = true

  tags = {
    Name = "${local.name_prefix_2}-alb"
  }
}

# Changing the port replaces the target group; the port in the name keeps names unique
# so the new one can be created and attached before the old one is deleted.
resource "aws_lb_target_group" "backend_2" {
  name        = "${local.name_prefix}-backend-2-${var.backend_2_container_port}"
  port        = var.backend_2_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc_2.vpc_id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.backend_2_health_check_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name_prefix}-backend-2-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Without a certificate: serve backend-2 over HTTP.
# With a certificate: redirect HTTP to HTTPS.
resource "aws_lb_listener" "backend_2_http" {
  load_balancer_arn = aws_lb.backend_2.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = local.backend_2_https_enabled ? "redirect" : "forward"
    target_group_arn = local.backend_2_https_enabled ? null : aws_lb_target_group.backend_2.arn

    dynamic "redirect" {
      for_each = local.backend_2_https_enabled ? [1] : []

      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

resource "aws_lb_listener" "backend_2_https" {
  count = local.backend_2_https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.backend_2.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.backend_2_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_2.arn
  }
}
