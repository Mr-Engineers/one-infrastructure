################################################################################
# Test-backend (test-backend-one): the backend's code against the same Supabase
# database, but on its own test_* tables (DB_TABLE_PREFIX). Reuses the backend's
# SUPABASE_URL / SUPABASE_KEY, has its own gateway token.
################################################################################

resource "aws_cloudwatch_log_group" "test_backend" {
  name              = "/ecs/${local.name_prefix}/test-backend"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "test_backend" {
  family                   = "${local.name_prefix}-test-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.test_backend_cpu
  memory                   = var.test_backend_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.test_backend_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "test-backend"
      image     = "${aws_ecr_repository.app["test-backend"].repository_url}:${var.test_backend_image_tag}"
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

      environment = [
        for key, value in merge(
          var.backend_environment,
          {
            APP_NAME        = "test-backend-one"
            BACKEND_2_URL   = local.backend_2_url
            DB_TABLE_PREFIX = var.test_backend_table_prefix
          },
          var.test_backend_environment,
          ) : {
          name  = key
          value = value
        }
      ]

      # Same SSM parameters as the backend (same database, see ssm.tf)
      secrets = concat(
        [
          for name, parameter in aws_ssm_parameter.backend_secret : {
            name      = name
            valueFrom = parameter.arn
          }
        ],
        [
          {
            # Own token, not the backend's (see ssm.tf)
            name      = "GATEWAY_TOKEN"
            valueFrom = aws_ssm_parameter.test_backend_gateway_token.arn
          },
        ],
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.test_backend.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "test-backend"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "test_backend" {
  name            = "${local.name_prefix}-test-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.test_backend.arn
  desired_count   = var.test_backend_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = module.vpc_main.private_subnet_ids
    security_groups  = [aws_security_group.test_backend.id]
    assign_public_ip = false
  }

  # Registers the test-backend in the namespace as http://test-backend:<port>
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      port_name      = "http"
      discovery_name = local.test_backend_service_connect_name

      client_alias {
        dns_name = local.test_backend_service_connect_name
        port     = var.backend_container_port
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.test_backend.name
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
