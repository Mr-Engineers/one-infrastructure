################################################################################
# GitHub Actions OIDC: lets workflows assume AWS roles without access keys
################################################################################

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  # GitHub may put immutable IDs into the token "sub" claim (owner@id/repo@id),
  # so accept both the plain and the ID-qualified form.
  github_owner_variants = var.github_org_id == null ? [var.github_org] : [var.github_org, "${var.github_org}@${var.github_org_id}"]

  github_oidc_subjects = {
    for key, repository in var.github_repositories : key => flatten([
      for owner in local.github_owner_variants : [
        for repo in [repository, "${repository}@*"] : [
          for branch in var.github_deploy_branches :
          "repo:${owner}/${repo}:ref:refs/heads/${branch}"
        ]
      ]
    ])
  }

  github_deploy_apps = {
    frontend = {
      repository     = var.github_repositories.frontend
      ecr_repository = aws_ecr_repository.app["frontend"].arn
      ecs_service    = aws_ecs_service.frontend.id
      task_role      = aws_iam_role.frontend_task.arn
    }
    backend = {
      repository     = var.github_repositories.backend
      ecr_repository = aws_ecr_repository.app["backend"].arn
      ecs_service    = aws_ecs_service.backend.id
      task_role      = aws_iam_role.backend_task.arn
    }
    # Key must match var.github_repositories (it indexes github_oidc_subjects)
    proxy_server = {
      repository     = var.github_repositories.proxy_server
      ecr_repository = aws_ecr_repository.app["proxy-server"].arn
      ecs_service    = aws_ecs_service.proxy_server.id
      task_role      = aws_iam_role.proxy_server_task.arn
    }
    backend_2 = {
      repository     = var.github_repositories.backend_2
      ecr_repository = aws_ecr_repository.app["backend-2"].arn
      ecs_service    = aws_ecs_service.backend_2.id
      task_role      = aws_iam_role.backend_2_task.arn
    }
    ai_agent = {
      repository     = var.github_repositories.ai_agent
      ecr_repository = aws_ecr_repository.app["ai-agent"].arn
      ecs_service    = aws_ecs_service.ai_agent.id
      task_role      = aws_iam_role.ai_agent_task.arn
    }
  }
}


data "aws_iam_policy_document" "github_deploy_assume_role" {
  for_each = local.github_deploy_apps

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_oidc_subjects[each.key]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  for_each = local.github_deploy_apps

  name               = "${local.name_prefix}-github-deploy-${replace(each.key, "_", "-")}"
  description        = "Assumed by GitHub Actions in ${var.github_org}/${each.value.repository} to deploy the ${replace(each.key, "_", "-")}"
  assume_role_policy = data.aws_iam_policy_document.github_deploy_assume_role[each.key].json
}

data "aws_iam_policy_document" "github_deploy" {
  for_each = local.github_deploy_apps

  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [each.value.ecr_repository]
  }

  # Task definition actions do not support resource-level permissions
  statement {
    sid = "EcsTaskDefinitions"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EcsDeploy"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = [each.value.ecs_service]
  }

  # Needed when registering a new task definition revision
  statement {
    sid     = "PassTaskRoles"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      each.value.task_role,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # The frontend build reads its VITE_* config from SSM (see ssm.tf)
  dynamic "statement" {
    for_each = each.key == "frontend" && length(aws_ssm_parameter.frontend_env) > 0 ? [1] : []

    content {
      sid       = "ReadBuildConfig"
      actions   = ["ssm:GetParameter", "ssm:GetParameters"]
      resources = [for parameter in aws_ssm_parameter.frontend_env : parameter.arn]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  for_each = local.github_deploy_apps

  name   = "deploy"
  role   = aws_iam_role.github_deploy[each.key].id
  policy = data.aws_iam_policy_document.github_deploy[each.key].json
}

################################################################################
# Infrastructure role: runs Terraform from the infrastructure repository
################################################################################

data "aws_iam_policy_document" "github_infrastructure_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_oidc_subjects["infrastructure"]
    }
  }
}

resource "aws_iam_role" "github_infrastructure" {
  name               = "${local.name_prefix}-github-infrastructure"
  description        = "Assumed by GitHub Actions in ${var.github_org}/${var.github_repositories.infrastructure} to run Terraform"
  assume_role_policy = data.aws_iam_policy_document.github_infrastructure_assume_role.json
}

# Terraform manages VPC, IAM, ECS, ECR, ... so the role needs broad permissions
resource "aws_iam_role_policy_attachment" "github_infrastructure" {
  role       = aws_iam_role.github_infrastructure.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
