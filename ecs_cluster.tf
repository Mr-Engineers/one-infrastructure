resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.main.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# Namespace for ECS Service Connect - lets services call each other by name
# (e.g. the frontend reaches the backend at http://backend:8000).
resource "aws_service_discovery_http_namespace" "main" {
  name        = "${local.name_prefix}.local"
  description = "Service Connect namespace for ${local.name_prefix}"
}
