################################################################################
# Backend secrets in SSM Parameter Store
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

data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  statement {
    sid       = "ReadBackendSecrets"
    actions   = ["ssm:GetParameters"]
    resources = [for parameter in aws_ssm_parameter.backend_secret : parameter.arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  count = length(var.backend_secret_names) > 0 ? 1 : 0

  name   = "read-backend-secrets"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets.json
}
