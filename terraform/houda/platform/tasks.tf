# Credentials are injected by ECS from Secrets Manager at task start
# ("secrets"), so they never appear in the task definition, the image or the
# repo. Only non-sensitive settings go in "environment".
locals {
  service_hostnames = {
    for name in local.discovered_services :
    name => "${name}.${aws_service_discovery_private_dns_namespace.local.name}"
  }

  # Same probe as the Dockerfiles' HEALTHCHECK. ECS uses it to replace broken
  # tasks and to take them out of Cloud Map DNS.
  container_health_check = {
    command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3)\" || exit 1"]
    interval    = 30
    timeout     = 5
    retries     = 3
    startPeriod = 120
  }
}

# -----------------------------------------------------------------------------
# Task Definition: API Gateway App (Port 3000)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "api_gateway_app" {
  family                   = "${var.project_name}-api-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution["api-gateway"].arn
  task_role_arn            = aws_iam_role.task["api-gateway"].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "api-gateway-app"
      image     = local.images["api-gateway-app"]
      essential = true
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "INVENTORY_SERVICE_URL", value = "http://${local.service_hostnames["inventory-app"]}:8080" },
        { name = "RABBITMQ_HOST", value = local.service_hostnames["rabbit-queue"] },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.main.id },
        { name = "COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.main.id },
      ]
      secrets = [
        { name = "RABBITMQ_USER", valueFrom = "${local.rabbitmq_secret_arn}:username::" },
        { name = "RABBITMQ_PASSWORD", valueFrom = "${local.rabbitmq_secret_arn}:password::" },
        { name = "RABBITMQ_QUEUE", valueFrom = "${local.rabbitmq_secret_arn}:queue::" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api-gateway"
        }
      }
    }
  ])
}

# -----------------------------------------------------------------------------
# Task Definition: Inventory App (Port 8080)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "inventory_app" {
  family                   = "${var.project_name}-inventory"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution["inventory"].arn
  task_role_arn            = aws_iam_role.task["inventory"].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "inventory-app"
      image     = local.images["inventory-app"]
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "INVENTORY_DB_HOST", value = local.inventory_db_host },
        { name = "INVENTORY_DB_PORT", value = "5432" },
      ]
      secrets = [
        { name = "INVENTORY_DB_USER", valueFrom = "${local.inventory_db_secret_arn}:username::" },
        { name = "INVENTORY_DB_PASSWORD", valueFrom = "${local.inventory_db_secret_arn}:password::" },
        { name = "INVENTORY_DB_NAME", valueFrom = "${local.inventory_db_secret_arn}:dbname::" },
      ]
      healthCheck = local.container_health_check
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "inventory"
        }
      }
    }
  ])
}

# -----------------------------------------------------------------------------
# Task Definition: Billing App (Port 8080)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "billing_app" {
  family                   = "${var.project_name}-billing"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution["billing"].arn
  task_role_arn            = aws_iam_role.task["billing"].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "billing-app"
      image     = local.images["billing-app"]
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "BILLING_DB_HOST", value = local.billing_db_host },
        { name = "BILLING_DB_PORT", value = "5432" },
        { name = "RABBITMQ_HOST", value = local.service_hostnames["rabbit-queue"] },
        { name = "RABBITMQ_PORT", value = "5672" },
        # billing-app logs with print(); without this, Python buffers the
        # output and processed orders show up in CloudWatch minutes late.
        { name = "PYTHONUNBUFFERED", value = "1" },
      ]
      secrets = [
        { name = "BILLING_DB_USER", valueFrom = "${local.billing_db_secret_arn}:username::" },
        { name = "BILLING_DB_PASSWORD", valueFrom = "${local.billing_db_secret_arn}:password::" },
        { name = "BILLING_DB_NAME", valueFrom = "${local.billing_db_secret_arn}:dbname::" },
        { name = "RABBITMQ_USER", valueFrom = "${local.rabbitmq_secret_arn}:username::" },
        { name = "RABBITMQ_PASSWORD", valueFrom = "${local.rabbitmq_secret_arn}:password::" },
        { name = "RABBITMQ_QUEUE", valueFrom = "${local.rabbitmq_secret_arn}:queue::" },
      ]
      healthCheck = local.container_health_check
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "billing"
        }
      }
    }
  ])
}
