output "rabbitmq_secret_arn" {
  description = "Secrets Manager ARN holding the RabbitMQ username/password/queue"
  value       = aws_secretsmanager_secret.rabbitmq.arn
}

output "efs_file_system_id" {
  description = "EFS file system backing rabbit-queue's data directory"
  value       = aws_efs_file_system.rabbitmq.id
}

output "task_definition_arn" {
  description = "ARN of the rabbit-queue ECS task definition (register a service against a cluster to run it)"
  value       = aws_ecs_task_definition.rabbit_queue.arn
}

output "task_execution_role_arn" {
  description = "IAM role ECS uses to pull the image, write logs, and read the secret"
  value       = aws_iam_role.rabbitmq_task_execution.arn
}

output "log_group_name" {
  description = "CloudWatch log group rabbit-queue writes to"
  value       = aws_cloudwatch_log_group.rabbitmq.name
}
