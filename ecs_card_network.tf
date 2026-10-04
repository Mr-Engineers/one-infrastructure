################################################################################
# Card network (card-network-agent, Network Portal MCP + REST) in cluster 2, public on
# the backend-2 load balancer on its own port (var.card_network_public_port), with the
# same certificate (it covers the ALB's DNS name, not a port).
#
# proxy-server reaches it as app "card_network" (card-network-agent/deploy/proxy-app.sql).
# MCP_API_KEY = MARKETPLACE_API_TOKEN, which proxy-server and the direct agent already have.
################################################################################

locals {
  # Public address of card-network
  card_network_url = "${local.backend_2_https_enabled ? "https" : "http"}://${aws_lb.backend_2.dns_name}:${var.card_network_public_port}"
}

resource "aws_cloudwatch_log_group" "card_network" {
  name              = "/ecs/${local.name_prefix}/card-network"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "card_network" {
  family                   = "${local.name_prefix}-card-network"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.card_network_cpu
  memory                   = var.card_network_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.card_network_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "card-network"
      image     = "${aws_ecr_repository.app["card-network"].repository_url}:${var.card_network_image_tag}"
      essential = true

      portMappings = [
        {
          name          = "http"
          containerPort = var.card_network_container_port
          protocol      = "tcp"
          appProtocol   = "http"
        },
      ]

      environment = [
        for key, value in merge(
          {
            MCP_HOST         = "0.0.0.0"
            NETWORK_MCP_PORT = tostring(var.card_network_container_port)
            # Empty: no Host header check (ALB DNS name / task IP on health checks); MCP_API_KEY guards access
            MCP_ALLOWED_HOSTS = ""
          },
          var.card_network_environment,
          ) : {
          name  = key
          value = value
        }
      ]

      # Injected from SSM Parameter Store at task start (see ssm.tf)
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = aws_ssm_parameter.dispute_database_url.arn
        },
        {
          # Bearer expected on /mcp, /v1/* and /demo/reset (existing token, see the header)
          name      = "MCP_API_KEY"
          valueFrom = aws_ssm_parameter.backend_2_secret["MARKETPLACE_API_TOKEN"].arn
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.card_network.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "card-network"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "card_network" {
  name            = "${local.name_prefix}-card-network"
  cluster         = aws_ecs_cluster.cluster_2.id
  task_definition = aws_ecs_task_definition.card_network.arn
  desired_count   = var.card_network_desired_count

  health_check_grace_period_seconds = 60

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = module.vpc_2.private_subnet_ids
    security_groups  = [aws_security_group.card_network.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.card_network.arn
    container_name   = "card-network"
    container_port   = var.card_network_container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_ecs_cluster_capacity_providers.cluster_2,
    aws_lb_listener.card_network,
  ]
}

# Changing the port replaces the target group; the port in the name keeps names unique
# so the new one can be created and attached before the old one is deleted.
resource "aws_lb_target_group" "card_network" {
  name        = "${local.name_prefix}-card-net-${var.card_network_container_port}"
  port        = var.card_network_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc_2.vpc_id

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
    Name = "${local.name_prefix}-card-network-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "card_network" {
  load_balancer_arn = aws_lb.backend_2.arn
  port              = var.card_network_public_port
  protocol          = local.backend_2_https_enabled ? "HTTPS" : "HTTP"
  ssl_policy        = local.backend_2_https_enabled ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null
  certificate_arn   = var.backend_2_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.card_network.arn
  }
}
