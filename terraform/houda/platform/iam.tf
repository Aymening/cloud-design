# Each app service gets its own pair of roles, so a compromised container can
# only reach what that one service needs:
#   - execution role: used by ECS itself to pull the image, write logs and
#     inject the service's secrets at startup
#   - task role: used by the running code; it only allows ECS Exec (shell
#     access for debugging), since none of the apps call AWS APIs
locals {
  service_secret_arns = {
    api-gateway = [local.rabbitmq_secret_arn]
    inventory   = [local.inventory_db_secret_arn]
    billing     = [local.billing_db_secret_arn, local.rabbitmq_secret_arn]
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# Execution roles
# -----------------------------------------------------------------------------
resource "aws_iam_role" "execution" {
  for_each = local.service_secret_arns

  name               = "${var.project_name}-${each.key}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

# Covers ECR pulls and CloudWatch Logs, but not reading any secret.
resource "aws_iam_role_policy_attachment" "execution_managed" {
  for_each = aws_iam_role.execution

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_service_secrets" {
  for_each = local.service_secret_arns

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = each.value
  }
}

resource "aws_iam_role_policy" "read_service_secrets" {
  for_each = local.service_secret_arns

  name   = "${var.project_name}-${each.key}-read-secrets"
  role   = aws_iam_role.execution[each.key].id
  policy = data.aws_iam_policy_document.read_service_secrets[each.key].json
}

# -----------------------------------------------------------------------------
# Task roles
# -----------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  for_each = local.service_secret_arns

  name               = "${var.project_name}-${each.key}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

data "aws_iam_policy_document" "ecs_exec" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecs_exec" {
  for_each = aws_iam_role.task

  name   = "${var.project_name}-${each.key}-ecs-exec"
  role   = each.value.id
  policy = data.aws_iam_policy_document.ecs_exec.json
}
