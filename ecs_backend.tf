resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.name_prefix}/backend"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name_prefix}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_cpu
  memory                   = var.backend_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.backend_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.app["backend"].repository_url}:${var.backend_image_tag}"
      essential = true

      portMappings = [
        {
          # Referenced by Service Connect (port_name below)
          name          = "http"
          containerPort = var.backend_container_port
          protocol      = "tcp"
          appProtocol   = "http"
        },
      ]

      environment = concat(
        [
          {
            # Public address of backend-2 in cluster 2 (via its load balancer, over the internet)
            name  = "BACKEND_2_URL"
            value = local.backend_2_url
          },
        ],
        [
          for key, value in var.backend_environment : {
            name  = key
            value = value
          }
        ],
      )

      # Injected from SSM Parameter Store at task start (see ssm.tf)
      secrets = concat(
        [
          for name, parameter in aws_ssm_parameter.backend_secret : {
            name      = name
            valueFrom = parameter.arn
          }
        ],
        [
          {
            # Requests carrying it came through proxy-server
            name      = "GATEWAY_TOKEN"
            valueFrom = aws_ssm_parameter.gateway_token.arn
          },
        ],
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "backend"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "backend" {
  name            = "${local.name_prefix}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = module.vpc_main.private_subnet_ids
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = false
  }

  # Registers the backend in the namespace as http://backend:<port>
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      port_name      = "http"
      discovery_name = local.backend_service_connect_name

      client_alias {
        dns_name = local.backend_service_connect_name
        port     = var.backend_container_port
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.backend.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "service-connect"
      }
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]
}
