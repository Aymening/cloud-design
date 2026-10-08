data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rabbitmq_task_execution" {
  name               = "${var.project_name}-rabbitmq-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "rabbitmq_task_execution_managed" {
  role       = aws_iam_role.rabbitmq_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The managed policy above covers ECR pulls and CloudWatch Logs, but not
# reading this specific secret - that needs its own grant.
data "aws_iam_policy_document" "rabbitmq_read_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.rabbitmq.arn]
  }
}

resource "aws_iam_role_policy" "rabbitmq_read_secret" {
  name   = "${var.project_name}-rabbitmq-read-secret"
  role   = aws_iam_role.rabbitmq_task_execution.id
  policy = data.aws_iam_policy_document.rabbitmq_read_secret.json
}

# Task role: the running container's identity. With EFS IAM authorization
# enabled (task_definition.tf), ECS mounts the volume with this role, so it
# may only mount and write the file system through the RabbitMQ access point.
resource "aws_iam_role" "rabbitmq_task" {
  name               = "${var.project_name}-rabbitmq-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
}

data "aws_iam_policy_document" "rabbitmq_efs_access" {
  statement {
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
    ]
    resources = [aws_efs_file_system.rabbitmq.arn]

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [aws_efs_access_point.rabbitmq.arn]
    }
  }
}

resource "aws_iam_role_policy" "rabbitmq_efs_access" {
  name   = "${var.project_name}-rabbitmq-efs-access"
  role   = aws_iam_role.rabbitmq_task.id
  policy = data.aws_iam_policy_document.rabbitmq_efs_access.json
}
