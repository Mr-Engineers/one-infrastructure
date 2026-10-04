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

output "proxy_server_public_url" {
  description = "Public address of the proxy-server (testing)."
  value       = "${local.https_enabled ? "https" : "http"}://${aws_lb.main.dns_name}:${var.proxy_server_public_port}"
}

output "ecr_test_backend_repository_url" {
  description = "URL of the test-backend ECR repository."
  value       = aws_ecr_repository.app["test-backend"].repository_url
}

output "ecs_test_backend_service_name" {
  description = "Name of the test-backend ECS service."
  value       = aws_ecs_service.test_backend.name
}

output "test_backend_internal_url" {
  description = "Address of the test-backend inside the cluster (Service Connect)."
  value       = local.test_backend_internal_url
}

output "ecr_ai_agent_repository_url" {
  description = "URL of the proxy AI agent ECR repository (purchasing-agent)."
  value       = aws_ecr_repository.app["ai-agent"].repository_url
}

output "ecr_ai_agent_direct_repository_url" {
  description = "URL of the direct AI agent ECR repository (purchasing-agent-test)."
  value       = aws_ecr_repository.app["ai-agent-direct"].repository_url
}

output "ecs_ai_agent_service_names" {
  description = "Names of the long-running AI agent ECS services, keyed by mode (proxy)."
  value       = { for mode, service in aws_ecs_service.ai_agent : mode => service.name }
}

output "ai_agent_direct_run_task" {
  description = "Everything needed to start the one-off direct AI agent (aws ecs run-task)."
  value = {
    cluster         = aws_ecs_cluster.main.name
    task_definition = aws_ecs_task_definition.ai_agent["direct"].family
    subnets         = module.vpc_main.private_subnet_ids
    security_group  = aws_security_group.ai_agent["direct"].id
    log_group       = aws_cloudwatch_log_group.ai_agent["direct"].name
    command = join(" ", [
      "aws ecs run-task --region ${var.aws_region}",
      "--cluster ${aws_ecs_cluster.main.name}",
      "--task-definition ${aws_ecs_task_definition.ai_agent["direct"].family}",
      "--launch-type FARGATE",
      "--network-configuration 'awsvpcConfiguration={subnets=[${join(",", module.vpc_main.private_subnet_ids)}],securityGroups=[${aws_security_group.ai_agent["direct"].id}],assignPublicIp=DISABLED}'",
    ])
  }
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

output "ecr_case_desk_repository_urls" {
  description = "URLs of the case-desk ECR repositories, keyed by prod (case-desk-agent) / test (case-desk-agent-test)."
  value       = { for key, case_desk in local.case_desks : key => aws_ecr_repository.app[case_desk.ecr_repository].repository_url }
}

output "ecs_case_desk_service_names" {
  description = "Names of the case-desk ECS services (cluster 1), keyed by prod / test."
  value       = { for key, service in aws_ecs_service.case_desk : key => service.name }
}

output "case_desk_internal_urls" {
  description = "Addresses of the case-desk services inside cluster 1 (Service Connect); prod is the upstream of proxy-server app case_desk."
  value       = local.case_desk_internal_urls
}

output "case_desk_test_dns_url" {
  description = "Address of case-desk-test through Cloud Map DNS, for one-off tasks (direct agent)."
  value       = local.case_desk_test_dns_url
}

output "ecr_card_network_repository_url" {
  description = "URL of the card-network ECR repository."
  value       = aws_ecr_repository.app["card-network"].repository_url
}

output "ecs_card_network_service_name" {
  description = "Name of the card-network ECS service (in cluster 2)."
  value       = aws_ecs_service.card_network.name
}

output "card_network_url" {
  description = "Public URL of card-network (backend-2 load balancer, own port); upstream of proxy-server app card_network."
  value       = local.card_network_url
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
