data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Public subnets: 10.0.0.0/24, 10.0.1.0/24, ...
  # Private subnets: 10.0.100.0/24, 10.0.101.0/24, ...
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 100)]

  nat_gateway_count = var.single_nat_gateway ? 1 : var.az_count

  # Name under which the backend is reachable from other services via ECS Service Connect
  backend_service_connect_name = "backend"
  backend_internal_url         = "http://${local.backend_service_connect_name}:${var.backend_container_port}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}
