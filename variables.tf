################################################################################
# General
################################################################################

variable "aws_region" {
  description = "AWS region where all resources are created."
  type        = string
}

variable "project_name" {
  description = "Project name, used as a prefix for resource names."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}

################################################################################
# Networking
################################################################################

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use (public + private subnet in each)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "The Application Load Balancer requires at least 2 availability zones."
  }
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cheaper) instead of one per AZ (highly available)."
  type        = bool
  default     = true
}

################################################################################
# Load balancer
################################################################################

variable "certificate_arn" {
  description = "ACM certificate ARN. If set, an HTTPS listener is created and HTTP is redirected to HTTPS."
  type        = string
  default     = null
}

################################################################################
# ECR
################################################################################

variable "ecr_image_retention_count" {
  description = "Number of most recent images kept in each ECR repository."
  type        = number
  default     = 20
}

variable "ecr_force_delete" {
  description = "Allow deleting ECR repositories that still contain images."
  type        = bool
  default     = false
}

################################################################################
# ECS
################################################################################

variable "log_retention_days" {
  description = "CloudWatch Logs retention for container logs, in days."
  type        = number
  default     = 14
}

variable "frontend_image_tag" {
  description = "Tag of the frontend image in ECR."
  type        = string
  default     = "latest"
}

variable "frontend_container_port" {
  description = "Port the frontend container listens on."
  type        = number
  default     = 8080
}

variable "frontend_cpu" {
  description = "Fargate CPU units for the frontend task (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "frontend_memory" {
  description = "Fargate memory (MiB) for the frontend task."
  type        = number
  default     = 512
}

variable "frontend_desired_count" {
  description = "Number of running frontend tasks."
  type        = number
  default     = 1
}

variable "frontend_health_check_path" {
  description = "Path used by the load balancer to check frontend health."
  type        = string
  default     = "/"
}

variable "frontend_env_parameter_names" {
  description = "Build-time config (VITE_*) of the frontend, stored as String parameters in SSM and read by the frontend CI."
  type        = list(string)
  default     = []
}

variable "backend_image_tag" {
  description = "Tag of the backend image in ECR."
  type        = string
  default     = "latest"
}

variable "backend_container_port" {
  description = "Port the backend container listens on."
  type        = number
  default     = 8000
}

variable "backend_cpu" {
  description = "Fargate CPU units for the backend task (256 = 0.25 vCPU)."
  type        = number
  default     = 512
}

variable "backend_memory" {
  description = "Fargate memory (MiB) for the backend task."
  type        = number
  default     = 1024
}

variable "backend_desired_count" {
  description = "Number of running backend tasks."
  type        = number
  default     = 1
}

variable "backend_environment" {
  description = "Plain-text environment variables passed to the backend container."
  type        = map(string)
  default     = {}
}

variable "backend_secret_names" {
  description = "Names of secret environment variables for the backend, stored as SecureString parameters in SSM."
  type        = list(string)
  default     = []
}

variable "proxy_server_image_tag" {
  description = "Tag of the proxy-server image in ECR."
  type        = string
  default     = "latest"
}

variable "proxy_server_container_port" {
  description = "Port the proxy-server container listens on."
  type        = number
  default     = 8080
}

variable "proxy_server_cpu" {
  description = "Fargate CPU units for the proxy-server task (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "proxy_server_memory" {
  description = "Fargate memory (MiB) for the proxy-server task."
  type        = number
  default     = 512
}

variable "proxy_server_desired_count" {
  description = "Number of running proxy-server tasks."
  type        = number
  default     = 1
}

variable "proxy_server_environment" {
  description = "Plain-text environment variables passed to the proxy-server container (BACKEND_URL is always set)."
  type        = map(string)
  default     = {}
}

variable "proxy_server_bedrock_model_ids" {
  description = "Bedrock models proxy-server may invoke on behalf of agents (SigV4 with the task role)."
  type        = list(string)
  default     = ["qwen.qwen3-32b-v1:0"]
}

variable "ai_agent_image" {
  description = "Full image URI of the AI agent. Null = the ai-agent ECR repository with ai_agent_image_tag."
  type        = string
  default     = null
}

variable "ai_agent_image_tag" {
  description = "Tag of the AI agent image in ECR."
  type        = string
  default     = "latest"
}

variable "ai_agent_bedrock_model_id" {
  description = "Bedrock model the AI agent requests through proxy-server (Qwen3 32B is available in-Region in eu-north-1)."
  type        = string
  default     = "qwen.qwen3-32b-v1:0"
}

variable "ai_agent_cpu" {
  description = "Fargate CPU units for the AI agent task (256 = 0.25 vCPU)."
  type        = number
  default     = 512
}

variable "ai_agent_memory" {
  description = "Fargate memory (MiB) for the AI agent task."
  type        = number
  default     = 1024
}

variable "ai_agent_desired_count" {
  description = "Number of running AI agent tasks. At most 1: parallel agents would order the same SKUs."
  type        = number
  default     = 1

  validation {
    condition     = var.ai_agent_desired_count <= 1
    error_message = "Run at most one AI agent task."
  }
}

variable "ai_agent_environment" {
  description = "Plain-text environment variables for the AI agent (POLL_INTERVAL_S, MAX_PARALLEL_SESSIONS, ...); override the defaults set in ecs_ai_agent.tf."
  type        = map(string)
  default     = {}
}

################################################################################
# Cluster 2: backend-2 in a separate VPC behind its own load balancer
################################################################################

variable "vpc_2_cidr" {
  description = "CIDR block of the cluster 2 VPC (should not overlap vpc_cidr, to allow peering later)."
  type        = string
  default     = "10.1.0.0/16"
}

variable "backend_2_certificate_arn" {
  description = "ACM certificate ARN for the backend-2 load balancer. If set, HTTPS is enabled and HTTP is redirected."
  type        = string
  default     = null
}

variable "backend_2_image_tag" {
  description = "Tag of the backend-2 image in ECR."
  type        = string
  default     = "latest"
}

variable "backend_2_container_port" {
  description = "Port the backend-2 container listens on."
  type        = number
  default     = 8000
}

variable "backend_2_cpu" {
  description = "Fargate CPU units for the backend-2 task (256 = 0.25 vCPU)."
  type        = number
  default     = 512
}

variable "backend_2_memory" {
  description = "Fargate memory (MiB) for the backend-2 task."
  type        = number
  default     = 1024
}

variable "backend_2_desired_count" {
  description = "Number of running backend-2 tasks."
  type        = number
  default     = 1
}

variable "backend_2_health_check_path" {
  description = "Path used by the load balancer to check backend-2 health."
  type        = string
  default     = "/health"
}

variable "backend_2_environment" {
  description = "Plain-text environment variables passed to the backend-2 container."
  type        = map(string)
  default     = {}
}

variable "backend_2_secret_names" {
  description = "Names of secret environment variables for backend-2, stored as SecureString parameters in SSM (SUPABASE_URL/KEY come from the backend's parameters)."
  type        = list(string)
  default     = ["MARKETPLACE_API_TOKEN", "MARKETPLACE_ADMIN_TOKEN"]
}

################################################################################
# GitHub Actions
################################################################################

variable "github_org" {
  description = "GitHub organization (or user) that owns the repositories."
  type        = string
}

variable "github_org_id" {
  description = "Numeric ID of the GitHub organization, used in ID-qualified OIDC subjects (owner@id). Null disables them."
  type        = number
  default     = null
}

variable "github_repositories" {
  description = "Names of the GitHub repositories allowed to assume the CI/CD roles."
  type = object({
    frontend       = string
    backend        = string
    proxy_server   = string
    backend_2      = string
    ai_agent       = string
    infrastructure = string
  })
}

variable "github_deploy_branches" {
  description = "Branches whose workflows may assume the CI/CD roles (wildcards allowed, e.g. \"release/*\")."
  type        = list(string)
  default     = ["main"]
}
