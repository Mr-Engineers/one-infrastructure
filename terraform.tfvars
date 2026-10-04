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

# AI agents: proxy = one-dev-ai-agent ECR (purchasing-agent CI),
# direct = one-dev-ai-agent-direct ECR (purchasing-agent-test CI)
ai_agent_cpu    = 512
ai_agent_memory = 1024
# proxy  = one-dev-ai-agent service, everything through proxy-server
# direct = one-dev-ai-agent-direct one-off task (run-task, no service): test-backend +
#          backend-2 + Bedrock without the proxy (tests)
ai_agent_desired_count = 1

# Case Desk: prod = case-desk-agent (through proxy-server), test = case-desk-agent-test
# (direct, own schema dispute_case_desk_test in the same database)
case_desk_image_tag      = "latest"
case_desk_container_port = 4102
case_desk_cpu            = 256
case_desk_memory         = 512
case_desk_desired_counts = {
  prod = 1
  test = 1
}
case_desk_environment = {
  DEMO_SEED = "dispute_v1"
}

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

# Card network (card-network-agent, Network Portal) in cluster 2, public on the backend-2
# load balancer: https://<alb-2>:8443 (same certificate as backend-2)
card_network_image_tag      = "latest"
card_network_container_port = 4101
card_network_public_port    = 8443
card_network_public_cidrs   = ["0.0.0.0/0"]
card_network_cpu            = 256
card_network_memory         = 512
card_network_desired_count  = 1
card_network_environment = {
  DEMO_SEED = "dispute_v1"
}

# GitHub Actions
github_org    = "Mr-Engineers"
github_org_id = 206612647

github_repositories = {
  frontend        = "one-frontend"
  backend         = "one-backend"
  proxy_server    = "proxy-server"
  backend_2       = "two-backend"
  infrastructure  = "one-infrastructure"
  ai_agent        = "purchasing-agent"
  ai_agent_direct = "purchasing-agent-test"
  test_backend    = "test-backend-one"
  case_desk       = "case-desk-agent"
  case_desk_test  = "case-desk-agent-test"
  card_network    = "card-network-agent"
}

github_deploy_branches = ["main", "feature/cicd"]
