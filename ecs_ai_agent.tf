################################################################################
# AI agent: long-running worker in cluster 1 (no inbound traffic)
#
# Every action of the agent goes through proxy-server, which decides what the
# agent may do. The agent can reach neither the backend (security groups) nor the
# gateway token the backend trusts.
#
# No ECR repository / CI yet. Until var.ai_agent_image is set the service is
# created with 0 tasks and a placeholder image.
################################################################################

locals {
  ai_agent_image         = coalesce(var.ai_agent_image, "public.ecr.aws/docker/library/busybox:latest")
  ai_agent_desired_count = var.ai_agent_image == null ? 0 : var.ai_agent_desired_count
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

      environment = concat(
        [
          {
            # The only API the agent talks to (via Service Connect)
            name  = "PROXY_URL"
            value = local.proxy_server_internal_url
          },
        ],
        [
          for key, value in var.ai_agent_environment : {
            name  = key
            value = value
          }
        ],
      )

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
  desired_count   = local.ai_agent_desired_count

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

  # Service Connect clients only see endpoints that exist when their tasks start
  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_ecs_service.proxy_server,
  ]
}
