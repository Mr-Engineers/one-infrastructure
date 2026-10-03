locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Resources of cluster 2 (separate VPC), e.g. one-dev-2-vpc
  name_prefix_2 = "${local.name_prefix}-2"

  # Name under which the backend is reachable from other services via ECS Service Connect
  backend_service_connect_name = "backend"
  backend_internal_url         = "http://${local.backend_service_connect_name}:${var.backend_container_port}"

  proxy_server_service_connect_name = "proxy-server"
  proxy_server_internal_url         = "http://${local.proxy_server_service_connect_name}:${var.proxy_server_container_port}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}
