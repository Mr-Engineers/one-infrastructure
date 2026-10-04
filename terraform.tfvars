aws_region   = "eu-north-1"
project_name = "one"
environment  = "dev"

tags = {
  Owner = "hackyeah2026"
}

# Networking
vpc_cidr           = "10.0.0.0/16"
az_count           = 2
single_nat_gateway = true

# Load balancer (set an ACM certificate ARN to enable HTTPS)
certificate_arn = "arn:aws:acm:eu-north-1:206135621036:certificate/22d9fed2-6f4c-4d4d-9d1e-ccbbc4225826"

# ECR
ecr_image_retention_count = 20
ecr_force_delete          = true

# ECS
log_retention_days = 14

frontend_image_tag         = "latest"
frontend_container_port    = 8080
frontend_cpu               = 256
frontend_memory            = 512
frontend_desired_count     = 1
frontend_health_check_path = "/"
frontend_env_parameter_names = [
  "VITE_API_BASE_URL",
  "VITE_SUPABASE_URL",
  "VITE_SUPABASE_PUBLISHABLE_KEY",
]

backend_image_tag      = "latest"
backend_container_port = 8000
backend_cpu            = 1024
backend_memory         = 2048
backend_desired_count  = 1
backend_environment = {
  APP_ENV   = "dev"
  APP_DEBUG = "false"
}
backend_secret_names = ["SUPABASE_URL", "SUPABASE_KEY"]

# Test copy of the backend (test-backend-one): same Supabase secrets, test_* tables
test_backend_image_tag     = "latest"
test_backend_cpu           = 256
test_backend_memory        = 512
test_backend_desired_count = 1
test_backend_table_prefix  = "test_"
test_backend_environment   = {}

proxy_server_image_tag      = "latest"
proxy_server_container_port = 8080
proxy_server_cpu            = 256
proxy_server_memory         = 512
proxy_server_desired_count  = 1
# Public access for testing: https://<alb>:8443 (narrow to your IP/32 if possible)
proxy_server_public_port  = 8443
proxy_server_public_cidrs = ["0.0.0.0/0"]

# AI agent (null image = one-dev-ai-agent ECR repository, pushed by purchasing-agent CI)
ai_agent_image         = null
ai_agent_cpu           = 512
ai_agent_memory        = 1024
ai_agent_desired_count = 1
# proxy = through proxy-server; direct = test-backend + backend-2 + Bedrock without the proxy (tests)
ai_agent_mode = "proxy"

# Cluster 2 (separate VPC): backend-2 behind its own public load balancer
vpc_2_cidr                  = "10.1.0.0/16"
backend_2_certificate_arn   = "arn:aws:acm:eu-north-1:206135621036:certificate/ce222c82-296d-481c-b69c-9b821ec5c734"
backend_2_image_tag         = "latest"
backend_2_container_port    = 8000
backend_2_cpu               = 512
backend_2_memory            = 1024
backend_2_desired_count     = 1
backend_2_health_check_path = "/health/live"
backend_2_environment = {
  APP_ENV   = "production" # development | test | production ("dev" fails validation)
  LOG_LEVEL = "INFO"
}
backend_2_secret_names = ["MARKETPLACE_API_TOKEN", "MARKETPLACE_ADMIN_TOKEN"]

# GitHub Actions
github_org    = "Mr-Engineers"
github_org_id = 206612647

github_repositories = {
  frontend       = "one-frontend"
  backend        = "one-backend"
  proxy_server   = "proxy-server"
  backend_2      = "two-backend"
  infrastructure = "one-infrastructure"
  ai_agent       = "purchasing-agent"
  test_backend   = "test-backend-one"
}

github_deploy_branches = ["main", "feature/cicd"]
