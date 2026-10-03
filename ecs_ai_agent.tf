################################################################################
# AI agent: long-running worker in cluster 1 (no inbound traffic, no internet)
#
# Every action of the agent - LLM calls included - goes through proxy-server, which
# decides what the agent may do. The agent has no network path to the backend and
# no Bedrock permissions of its own (see security_groups.tf and iam.tf).
#
# Image: ECR repository "ai-agent", pushed by the purchasing-agent CI
# (var.ai_agent_image overrides it).
################################################################################

locals {
  ai_agent_image = coalesce(var.ai_agent_image, "${aws_ecr_repository.app["ai-agent"].repository_url}:${var.ai_agent_image_tag}")
}

resource "aws_cloudwatch_log_group" "ai_agent" {
  name              = "/ecs/${local.name_prefix}/ai-agent"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "ai_agent" {
  family                   = "${local.name_prefix}-ai-agent"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ai_agent_cpu
  memory                   = var.ai_agent_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ai_agent_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "ai-agent"
      image     = local.ai_agent_image
      essential = true

      # App ids match proxy.apps in the proxy-server database.
      # TODO: set PROXY_URL (sessions, approvals) once proxy-server serves /v1/sessions.
      environment = [
        for key, value in merge(
          {
            AWS_REGION   = var.aws_region
            LLM_BASE_URL = "${local.proxy_server_internal_url}/v1"
            LLM_MODEL    = var.ai_agent_bedrock_model_id
            # Any non-empty value: stops the agent from signing Bedrock tokens itself.
            # The proxy drops the agent's Authorization header and adds its own credentials.
            LLM_API_KEY     = "via-proxy"
            WAREHOUSE_URL   = "${local.proxy_server_internal_url}/apps/warehouse"
            MARKETPLACE_URL = "${local.proxy_server_internal_url}/apps/marketplace"
          },
          var.ai_agent_environment,
          ) : {
          name  = key
          value = value
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ai_agent.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ai-agent"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "ai_agent" {
  name            = "${local.name_prefix}-ai-agent"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ai_agent.arn
  desired_count   = var.ai_agent_desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = module.vpc_main.private_subnet_ids
    security_groups  = [aws_security_group.ai_agent.id]
    assign_public_ip = false
  }

  # Client-only Service Connect: lets the agent resolve http://proxy-server:<port>
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Service Connect clients only see endpoints that exist when their tasks start.
  # Without internet access the agent cannot start before the VPC endpoints exist.
  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_ecs_service.proxy_server,
    aws_vpc_endpoint.interface,
    aws_vpc_endpoint.s3,
  ]
}
