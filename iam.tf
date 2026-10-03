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

resource "aws_iam_role" "test_backend_task" {
  name               = "${local.name_prefix}-test-backend-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role" "proxy_server_task" {
  name               = "${local.name_prefix}-proxy-server-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

data "aws_iam_policy_document" "proxy_server_bedrock" {
  statement {
    sid       = "InvokeModel"
    actions   = ["bedrock:InvokeModel"]
    resources = [for model_id in var.proxy_server_bedrock_model_ids : "arn:aws:bedrock:${var.aws_region}::foundation-model/${model_id}"]
  }
}

resource "aws_iam_role_policy" "proxy_server_bedrock" {
  name   = "bedrock-inference"
  role   = aws_iam_role.proxy_server_task.id
  policy = data.aws_iam_policy_document.proxy_server_bedrock.json
}

# No policies: the agent reaches the LLM only through proxy-server
resource "aws_iam_role" "ai_agent_task" {
  name               = "${local.name_prefix}-ai-agent-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role" "backend_2_task" {
  name               = "${local.name_prefix}-backend-2-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}
