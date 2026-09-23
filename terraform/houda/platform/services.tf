# The three app services share the same settings:
#   - private subnets only, no public IP (outbound goes through the NAT)
#   - desired_count is only the starting point: auto-scaling owns it after
#     the first apply, so Terraform ignores later changes to it
#   - the circuit breaker rolls a deployment back if its new tasks keep failing
#   - enable_execute_command allows `aws ecs execute-command` for debugging
locals {
  app_security_group_ids = [local.app_security_group_id, aws_security_group.services_internal.id]
}

# API Gateway ECS Service (Traffic routed via ALB)
resource "aws_ecs_service" "api_gateway" {
  name                              = "api-gateway-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.api_gateway_app.arn
  desired_count                     = var.autoscaling_min_capacity
  launch_type                       = "FARGATE"
  enable_execute_command            = true
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = local.app_security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_gateway.arn
    container_name   = "api-gateway-app"
    container_port   = 3000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  # The HTTPS listener is what attaches the target group to the load
  # balancer; ECS rejects a target group that isn't attached yet.
  depends_on = [aws_lb_listener.https]
}

# Inventory ECS Service (Internal DNS: inventory-app.local)
resource "aws_ecs_service" "inventory" {
  name                   = "inventory-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.inventory_app.arn
  desired_count          = var.autoscaling_min_capacity
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = local.app_security_group_ids
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this["inventory-app"].arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# Billing ECS Service (Internal DNS: billing-app.local). Several billing
# tasks can run at once: RabbitMQ hands each message to only one consumer.
resource "aws_ecs_service" "billing" {
  name                   = "billing-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.billing_app.arn
  desired_count          = var.autoscaling_min_capacity
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = local.app_security_group_ids
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this["billing-app"].arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# RabbitMQ ECS Service (Internal DNS: rabbit-queue.local), running the task
# definition from aymen/04-messaging. Exactly one broker, never auto-scaled:
# its data directory lives on EFS, and two brokers must never share it, so
# deployments stop the old task before starting the new one.
resource "aws_ecs_service" "rabbit_queue" {
  name                               = "rabbit-queue-service"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = local.messaging.task_definition_arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [local.rabbitmq_security_group_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this["rabbit-queue"].arn
  }
}
