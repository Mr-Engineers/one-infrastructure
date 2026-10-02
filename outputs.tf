################################################################################
# Networking
################################################################################

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
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

output "backend_internal_url" {
  description = "Address of the backend inside the cluster (Service Connect)."
  value       = local.backend_internal_url
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
