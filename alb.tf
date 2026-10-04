locals {
  https_enabled = var.certificate_arn != null
}

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc_main.public_subnet_ids

  drop_invalid_header_fields = true

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# Changing the port replaces the target group; the port in the name keeps names unique
# so the new one can be created and attached before the old one is deleted.
resource "aws_lb_target_group" "frontend" {
  name        = "${local.name_prefix}-frontend-${var.frontend_container_port}"
  port        = var.frontend_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc_main.vpc_id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.frontend_health_check_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name_prefix}-frontend-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Without a certificate: serve the app over HTTP.
# With a certificate: redirect HTTP to HTTPS.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = local.https_enabled ? "redirect" : "forward"
    target_group_arn = local.https_enabled ? null : aws_lb_target_group.frontend.arn

    dynamic "redirect" {
      for_each = local.https_enabled ? [1] : []

      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

################################################################################
# Proxy-server on its own port (testing): the frontend already owns /api/ on 443
# and there is no custom domain for host-based routing.
################################################################################

resource "aws_lb_target_group" "proxy_server" {
  name        = "${local.name_prefix}-proxy-${var.proxy_server_container_port}"
  port        = var.proxy_server_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc_main.vpc_id

  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name_prefix}-proxy-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Same certificate as 443 (it covers the ALB's DNS name, not a port)
resource "aws_lb_listener" "proxy_server" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.proxy_server_public_port
  protocol          = local.https_enabled ? "HTTPS" : "HTTP"
  ssl_policy        = local.https_enabled ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy_server.arn
  }
}
