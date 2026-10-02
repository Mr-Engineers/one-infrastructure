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
    infrastructure = string
  })
}

variable "github_deploy_branches" {
  description = "Branches whose workflows may assume the CI/CD roles (wildcards allowed, e.g. \"release/*\")."
  type        = list(string)
  default     = ["main"]
}
