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

      # ECS ignores the Dockerfile HEALTHCHECK. This one only checks that
      # RabbitMQ accepts connections on 5672 (bash's /dev/tcp, no extra
      # tools), so it doesn't depend on the node name resolving like
      # rabbitmq-diagnostics does. ECS replaces the task if it stops.
      healthCheck = {
        command     = ["CMD-SHELL", "bash -c '</dev/tcp/127.0.0.1/5672' || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }

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
