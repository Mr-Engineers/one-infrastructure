data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

################################################################################
# Task execution role: used by the ECS agent to pull images and write logs
################################################################################

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name_prefix}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################################################################
# Task roles: permissions of the application code itself (add policies as needed)
################################################################################

resource "aws_iam_role" "frontend_task" {
  name               = "${local.name_prefix}-frontend-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role" "backend_task" {
  name               = "${local.name_prefix}-backend-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role" "proxy_server_task" {
  name               = "${local.name_prefix}-proxy-server-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role" "ai_agent_task" {
  name               = "${local.name_prefix}-ai-agent-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

# AI agent: Bedrock inference on the configured model only
data "aws_iam_policy_document" "ai_agent_bedrock" {
  statement {
    sid       = "InvokeModel"
    actions   = ["bedrock:InvokeModel"]
    resources = ["arn:aws:bedrock:${var.aws_region}::foundation-model/${var.ai_agent_bedrock_model_id}"]
  }

  # The agent calls the OpenAI-compatible endpoint with a short-term bearer token
  # signed with this role's credentials
  statement {
    sid       = "CallWithBearerToken"
    actions   = ["bedrock:CallWithBearerToken"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ai_agent_bedrock" {
  name   = "bedrock-inference"
  role   = aws_iam_role.ai_agent_task.id
  policy = data.aws_iam_policy_document.ai_agent_bedrock.json
}

resource "aws_iam_role" "backend_2_task" {
  name               = "${local.name_prefix}-backend-2-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}
