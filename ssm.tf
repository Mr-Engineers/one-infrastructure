################################################################################
# Secrets in SSM Parameter Store
#
# Terraform only creates the parameters with a placeholder value. Set the real
# values outside Terraform, so they never end up in code or state:
#   aws ssm put-parameter --overwrite --type SecureString \
#     --name /one/dev/backend/SUPABASE_KEY --value '...'
################################################################################

resource "aws_ssm_parameter" "backend_secret" {
  for_each = toset(var.backend_secret_names)

  name        = "/${var.project_name}/${var.environment}/backend/${each.key}"
  description = "Backend secret ${each.key}, injected into the container as an environment variable"
  type        = "SecureString"
  value       = "CHANGE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

# Shared by proxy-server and the backend (Authorization: Bearer). The backend trusts the
# actor and allows purchase orders only with it, so it must never reach the AI agent.
#   aws ssm put-parameter --overwrite --type SecureString \
#     --name /one/dev/gateway/GATEWAY_TOKEN --value "$(openssl rand -hex 32)"
resource "aws_ssm_parameter" "gateway_token" {
  name        = "/${var.project_name}/${var.environment}/gateway/GATEWAY_TOKEN"
  description = "Shared secret between proxy-server and the backend"
  type        = "SecureString"
  value       = "CHANGE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

# Frontend build config (VITE_*). Vite inlines these into the JS bundle, so the
# frontend CI reads them when building the image (--build-arg), not ECS at runtime.
# Not secret (everything in the bundle is public), hence plain String.
#   aws ssm put-parameter --overwrite --type String \
#     --name /one/dev/frontend/VITE_SUPABASE_URL --value 'https://<project>.supabase.co'
# A change takes effect after the next frontend build (push or workflow_dispatch).
# VITE_API_BASE_URL left at CHANGE_ME is skipped (the app defaults to /api).
resource "aws_ssm_parameter" "frontend_env" {
  for_each = toset(var.frontend_env_parameter_names)

  name        = "/${var.project_name}/${var.environment}/frontend/${each.key}"
  description = "Frontend build config ${each.key}, inlined into the browser bundle"
  type        = "String"
  value       = "CHANGE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

# The AI agent's key for proxy-server (Authorization: Bearer). Only identifies the agent;
# proxy-server decides what it may do.
#   aws ssm put-parameter --overwrite --type SecureString \
#     --name /one/dev/ai-agent/AGENT_KEY --value '...'
resource "aws_ssm_parameter" "ai_agent_key" {
  name        = "/${var.project_name}/${var.environment}/ai-agent/AGENT_KEY"
  description = "AI agent key for proxy-server"
  type        = "SecureString"
  value       = "CHANGE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

# backend-2 (marketplace) runtime secrets. SUPABASE_URL / SUPABASE_KEY are shared with the
# backend (backend_secret above). MARKETPLACE_API_TOKEN is required with APP_ENV=production
# (callers send it as Bearer).
#   aws ssm put-parameter --overwrite --type SecureString \
#     --name /one/dev/backend-2/MARKETPLACE_API_TOKEN --value "$(openssl rand -hex 32)"
resource "aws_ssm_parameter" "backend_2_secret" {
  for_each = toset(var.backend_2_secret_names)

  name        = "/${var.project_name}/${var.environment}/backend-2/${each.key}"
  description = "Backend-2 secret ${each.key}, injected into the container as an environment variable"
  type        = "SecureString"
  value       = "CHANGE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "proxy_server_database_url" {
  name        = "/${var.project_name}/${var.environment}/proxy-server/DATABASE_URL"
  description = "proxy-server Postgres connection string"
  type        = "SecureString"
  value       = "CHANGE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}


data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  statement {
    sid     = "ReadSecrets"
    actions = ["ssm:GetParameters"]
    resources = concat(
      [for parameter in aws_ssm_parameter.backend_secret : parameter.arn],
      [for parameter in aws_ssm_parameter.backend_2_secret : parameter.arn],
      [
        aws_ssm_parameter.gateway_token.arn, aws_ssm_parameter.proxy_server_database_url.arn,
        aws_ssm_parameter.proxy_server_database_url.arn,
        aws_ssm_parameter.ai_agent_key.arn,
      ],
    )
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name   = "read-secrets"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets.json
}

moved {
  from = aws_iam_role_policy.ecs_task_execution_secrets[0]
  to   = aws_iam_role_policy.ecs_task_execution_secrets
}
