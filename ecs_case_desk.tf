################################################################################
# Case Desk (dispute-ops MCP + REST) in cluster 1, two services from two repositories:
#
# "prod" (one-dev-case-desk, case-desk-agent): reached by agents only through proxy-server
# (app "case_desk", see case-desk-agent/deploy/proxy-app.sql). Schema dispute_case_desk.
# MCP_API_KEY = the backend's GATEWAY_TOKEN, which proxy-server already sends as Bearer.
#
# "test" (one-dev-case-desk-test, case-desk-agent-test): for the direct agent (tests), like
# the test-backend: same database, own schema dispute_case_desk_test (DB_SCHEMA).
# MCP_API_KEY = the test-backend's gateway token, which the direct agent already gets.
#
# Images: prod -> ECR "case-desk", test -> ECR "case-desk-test", each pushed by its repo's CI.
################################################################################

locals {
  case_desks = {
    prod = {
      name           = "case-desk"
      app_name       = "case-desk-agent"
      ecr_repository = "case-desk"
      environment    = {}
      api_key_arn    = aws_ssm_parameter.gateway_token.arn
      # Cloud Map DNS for one-off tasks (run-task has no Service Connect)
      cloud_map = false
    }
    test = {
      name           = "case-desk-test"
      app_name       = "case-desk-agent-test"
      ecr_repository = "case-desk-test"
      environment = {
        DB_SCHEMA = "dispute_case_desk_test"
      }
      api_key_arn = aws_ssm_parameter.test_backend_gateway_token.arn
      cloud_map   = true
    }
  }
}

resource "aws_cloudwatch_log_group" "case_desk" {
  for_each = local.case_desks

  name              = "/ecs/${local.name_prefix}/${each.value.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "case_desk" {
  for_each = local.case_desks

  family                   = "${local.name_prefix}-${each.value.name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.case_desk_cpu
  memory                   = var.case_desk_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.case_desk_task[each.key].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = "${aws_ecr_repository.app[each.value.ecr_repository].repository_url}:${var.case_desk_image_tag}"
      essential = true

      portMappings = [
        {
          # Referenced by Service Connect (port_name below)
          name          = "http"
          containerPort = var.case_desk_container_port
          protocol      = "tcp"
          appProtocol   = "http"
        },
      ]

      environment = [
        for key, value in merge(
          {
            MCP_HOST           = "0.0.0.0"
            CASE_DESK_MCP_PORT = tostring(var.case_desk_container_port)
            # Empty: no Host header check (the Host is the Service Connect name); MCP_API_KEY guards access
            MCP_ALLOWED_HOSTS = ""
          },
          each.value.environment,
          var.case_desk_environment,
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
          valueFrom = each.value.api_key_arn
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.case_desk[each.key].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.value.name
        }
      }
    },
  ])
}

resource "aws_ecs_service" "case_desk" {
  for_each = local.case_desks

  name            = "${local.name_prefix}-${each.value.name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.case_desk[each.key].arn
  desired_count   = var.case_desk_desired_counts[each.key]

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = module.vpc_main.private_subnet_ids
    security_groups  = [aws_security_group.case_desk[each.key].id]
    assign_public_ip = false
  }

  # Registers the service in the namespace as http://<name>:<port>
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      port_name      = "http"
      discovery_name = each.value.name

      client_alias {
        dns_name = each.value.name
        port     = var.case_desk_container_port
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.case_desk[each.key].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "service-connect"
      }
    }
  }

  # Test copy only: also <name>.<name_prefix>.internal (Cloud Map DNS) for the direct agent
  dynamic "service_registries" {
    for_each = each.value.cloud_map ? [aws_service_discovery_service.case_desk_test.arn] : []

    content {
      registry_arn = service_registries.value
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]
}

resource "aws_service_discovery_service" "case_desk_test" {
  name = local.case_desks.test.name

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.internal.id
    routing_policy = "MULTIVALUE"

    dns_records {
      type = "A"
      ttl  = 10
    }
  }
}
