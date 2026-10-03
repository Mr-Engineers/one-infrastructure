################################################################################
# Cluster 2 (separate VPC): backend-2 behind its own public load balancer
################################################################################

resource "aws_ecs_cluster" "cluster_2" {
  name = "${local.name_prefix}-cluster-2"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "cluster_2" {
  cluster_name       = aws_ecs_cluster.cluster_2.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_cloudwatch_log_group" "backend_2" {
  name              = "/ecs/${local.name_prefix}/backend-2"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "backend_2" {
  family                   = "${local.name_prefix}-backend-2"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.backend_2_cpu
  memory                   = var.backend_2_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.backend_2_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "backend-2"
      image     = "${aws_ecr_repository.app["backend-2"].repository_url}:${var.backend_2_image_tag}"
      essential = true

      portMappings = [
        {
          name          = "http"
          containerPort = var.backend_2_container_port
          protocol      = "tcp"
          appProtocol   = "http"
        },
      ]

      environment = [
        for key, value in var.backend_2_environment : {
          name  = key
          value = value
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend_2.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "backend-2"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "backend_2" {
  name            = "${local.name_prefix}-backend-2"
  cluster         = aws_ecs_cluster.cluster_2.id
  task_definition = aws_ecs_task_definition.backend_2.arn
  desired_count   = var.backend_2_desired_count

  health_check_grace_period_seconds = 60

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = module.vpc_2.private_subnet_ids
    security_groups  = [aws_security_group.backend_2.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_2.arn
    container_name   = "backend-2"
    container_port   = var.backend_2_container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_ecs_cluster_capacity_providers.cluster_2,
    aws_lb_listener.backend_2_http,
  ]
}
