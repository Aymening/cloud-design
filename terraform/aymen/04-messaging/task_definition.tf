resource "aws_cloudwatch_log_group" "rabbitmq" {
  name              = "/ecs/${var.project_name}-rabbit-queue"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "rabbit_queue" {
  family                   = "${var.project_name}-rabbit-queue"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.rabbitmq_task_execution.arn
  task_role_arn            = aws_iam_role.rabbitmq_task.arn

  volume {
    name = "rabbitmq-data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.rabbitmq.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.rabbitmq.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "rabbit-queue"
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = 5672
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "rabbitmq-data"
          containerPath = "/var/lib/rabbitmq"
        }
      ]

      secrets = [
        { name = "RABBITMQ_USER", valueFrom = "${aws_secretsmanager_secret.rabbitmq.arn}:username::" },
        { name = "RABBITMQ_PASSWORD", valueFrom = "${aws_secretsmanager_secret.rabbitmq.arn}:password::" },
        { name = "RABBITMQ_QUEUE", valueFrom = "${aws_secretsmanager_secret.rabbitmq.arn}:queue::" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.rabbitmq.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "rabbit-queue"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-rabbit-queue"
  }
}
