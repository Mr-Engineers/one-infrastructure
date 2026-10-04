resource "aws_cloudwatch_log_group" "proxy_server" {
  name              = "/ecs/${local.name_prefix}/proxy-server"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "proxy_server" {
  family                   = "${local.name_prefix}-proxy-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.proxy_server_cpu
  memory                   = var.proxy_server_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.proxy_server_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "proxy-server"
      image     = "${aws_ecr_repository.app["proxy-server"].repository_url}:${var.proxy_server_image_tag}"
      essential = true

      portMappings = [
        {
          # Referenced by Service Connect (port_name below)
          name          = "http"
          containerPort = var.proxy_server_container_port
          protocol      = "tcp"
          appProtocol   = "http"
        },
      ]

      environment = concat(
        [
          {
            # Internal backend address (via Service Connect)
            name  = "BACKEND_URL"
            value = local.backend_internal_url
          },
        ],
        [
          for key, value in var.proxy_server_environment : {
            name  = key
            value = value
          }
        ],
      )

      secrets = [
        {
          # Sent to the backend as Authorization: Bearer (see ssm.tf)
          name      = "GATEWAY_TOKEN"
          valueFrom = aws_ssm_parameter.gateway_token.arn
        },
        {
          name      = "DATABASE_URL"
          valueFrom = aws_ssm_parameter.proxy_server_database_url.arn
        },
        {
          # Same token the marketplace (backend-2) expects as Bearer
          name      = "MARKETPLACE_API_TOKEN"
          valueFrom = aws_ssm_parameter.backend_2_secret["MARKETPLACE_API_TOKEN"].arn
        },
        {
          # Admin API (/api/v1) verifies frontend Supabase JWTs against this project's JWKS
          name      = "SUPABASE_URL"
          valueFrom = aws_ssm_parameter.proxy_server_supabase_url.arn
        },
        {
          # HS256 tokens (legacy Supabase JWT secret); the proxy ignores the CHANGE_ME placeholder
          name      = "SUPABASE_JWT_SECRET"
          valueFrom = aws_ssm_parameter.proxy_server_supabase_jwt_secret.arn
        },
        {
          name      = "TYPESAFE_API_KEY"
          valueFrom = aws_ssm_parameter.proxy_server_typesafe_api_key.arn
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.proxy_server.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "proxy-server"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "proxy_server" {
  name            = "${local.name_prefix}-proxy-server"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.proxy_server.arn
  desired_count   = var.proxy_server_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = module.vpc_main.private_subnet_ids
    security_groups  = [aws_security_group.proxy_server.id]
    assign_public_ip = false
  }

  # Public access for testing (alb.tf, listener on var.proxy_server_public_port)
  load_balancer {
    target_group_arn = aws_lb_target_group.proxy_server.arn
    container_name   = "proxy-server"
    container_port   = var.proxy_server_container_port
  }

  # Resolves http://backend:<port> and registers the proxy as http://proxy-server:<port>
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      port_name      = "http"
      discovery_name = local.proxy_server_service_connect_name

      client_alias {
        dns_name = local.proxy_server_service_connect_name
        port     = var.proxy_server_container_port
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.proxy_server.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "service-connect"
      }
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Service Connect clients only see endpoints that exist when their tasks start
  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_ecs_service.backend,
    aws_lb_listener.proxy_server,
  ]
}
