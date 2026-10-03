################################################################################
# Networking
################################################################################

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc_main.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc_main.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc_main.private_subnet_ids
}

output "nat_public_ips" {
  description = "Public IPs of the cluster 1 NAT Gateway(s): the source address cluster 2 sees for calls from cluster 1."
  value       = module.vpc_main.nat_public_ips
}

output "vpc_2_id" {
  description = "ID of the cluster 2 VPC."
  value       = module.vpc_2.vpc_id
}

################################################################################
# Load balancer
################################################################################

output "alb_dns_name" {
  description = "Public DNS name of the load balancer."
  value       = aws_lb.main.dns_name
}

output "app_url" {
  description = "Public URL of the application."
  value       = "${local.https_enabled ? "https" : "http"}://${aws_lb.main.dns_name}"
}

################################################################################
# ECR (used by CI/CD)
################################################################################

output "ecr_frontend_repository_url" {
  description = "URL of the frontend ECR repository."
  value       = aws_ecr_repository.app["frontend"].repository_url
}

output "ecr_backend_repository_url" {
  description = "URL of the backend ECR repository."
  value       = aws_ecr_repository.app["backend"].repository_url
}

output "ecr_proxy_server_repository_url" {
  description = "URL of the proxy-server ECR repository."
  value       = aws_ecr_repository.app["proxy-server"].repository_url
}

output "ecr_backend_2_repository_url" {
  description = "URL of the backend-2 ECR repository."
  value       = aws_ecr_repository.app["backend-2"].repository_url
}

################################################################################
# ECS (used by CI/CD)
################################################################################

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "ecs_frontend_service_name" {
  description = "Name of the frontend ECS service."
  value       = aws_ecs_service.frontend.name
}

output "ecs_backend_service_name" {
  description = "Name of the backend ECS service."
  value       = aws_ecs_service.backend.name
}

output "ecs_proxy_server_service_name" {
  description = "Name of the proxy-server ECS service."
  value       = aws_ecs_service.proxy_server.name
}

output "backend_internal_url" {
  description = "Address of the backend inside the cluster (Service Connect)."
  value       = local.backend_internal_url
}

output "proxy_server_internal_url" {
  description = "Address of the proxy-server inside the cluster (Service Connect)."
  value       = local.proxy_server_internal_url
}

output "ecs_ai_agent_service_name" {
  description = "Name of the AI agent ECS service."
  value       = aws_ecs_service.ai_agent.name
}

output "ecs_cluster_2_name" {
  description = "Name of the cluster 2 ECS cluster."
  value       = aws_ecs_cluster.cluster_2.name
}

output "ecs_backend_2_service_name" {
  description = "Name of the backend-2 ECS service (in cluster 2)."
  value       = aws_ecs_service.backend_2.name
}

output "backend_2_url" {
  description = "Public URL of backend-2 (its load balancer), passed to the backend as BACKEND_2_URL."
  value       = local.backend_2_url
}

################################################################################
# GitHub Actions
################################################################################

output "github_deploy_role_arns" {
  description = "Role ARNs for app deploy workflows (aws-actions/configure-aws-credentials role-to-assume)."
  value       = { for app, role in aws_iam_role.github_deploy : app => role.arn }
}

output "github_infrastructure_role_arn" {
  description = "Role ARN for the Terraform workflow in the infrastructure repository."
  value       = aws_iam_role.github_infrastructure.arn
}
