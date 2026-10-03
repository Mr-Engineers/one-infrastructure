################################################################################
# AI agent: long-running worker in cluster 1 (no inbound traffic)
#
# var.ai_agent_mode = "proxy" (default): every action of the agent goes through
# proxy-server, which decides what the agent may do: PROXY_URL/v1 (LLM),
# PROXY_URL/apps/warehouse, PROXY_URL/apps/marketplace. No internet, no IAM
# permissions; the backend does not accept traffic from the agent.
#
# var.ai_agent_mode = "direct" (tests): the agent skips the proxy and calls the
# test-backend (Service Connect), backend-2 (its load balancer) and Bedrock (task role)
# itself. Security group rules and the Bedrock policy exist only in this mode.
#
# Image: ECR repository "ai-agent", pushed by the purchasing-agent CI
# (var.ai_agent_image overrides it).
################################################################################

locals {
  ai_agent_image = coalesce(var.ai_agent_image, "${aws_ecr_repository.app["ai-agent"].repository_url}:${var.ai_agent_image_tag}")

  # The agent derives LLM_BASE_URL, WAREHOUSE_URL and MARKETPLACE_URL from PROXY_URL
  ai_agent_mode_environment = local.ai_agent_direct ? {
    AGENT_MODE      = "direct"
    LLM_BASE_URL    = "https://bedrock-runtime.${var.aws_region}.amazonaws.com/openai/v1"
    WAREHOUSE_URL   = "${local.test_backend_internal_url}/api/v1"
    MARKETPLACE_URL = local.backend_2_url
    } : {
    AGENT_MODE = "proxy"
    PROXY_URL  = local.proxy_server_internal_url
  }

  ai_agent_mode_secrets = local.ai_agent_direct ? {
    # Bearer tokens of the apps themselves (proxy-server adds them in proxy mode)
    WAREHOUSE_TOKEN   = aws_ssm_parameter.test_backend_gateway_token.arn
    MARKETPLACE_TOKEN = aws_ssm_parameter.backend_2_secret["MARKETPLACE_API_TOKEN"].arn
    } : {
    # Sent to proxy-server as Authorization: Bearer (see ssm.tf)
    AGENT_KEY = aws_ssm_parameter.ai_agent_key.arn
  }
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

      environment = [
        for key, value in merge(
          {
            AWS_REGION = var.aws_region
            LLM_MODEL  = var.ai_agent_bedrock_model_id
          },
          local.ai_agent_mode_environment,
          var.ai_agent_environment,
          ) : {
          name  = key
          value = value
        }
      ]

      secrets = [
        for name, arn in local.ai_agent_mode_secrets : {
          name      = name
          valueFrom = arn
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
  # (and http://test-backend:<port> in direct mode)
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
    aws_ecs_service.test_backend,
    aws_vpc_endpoint.interface,
    aws_vpc_endpoint.s3,
  ]
}
