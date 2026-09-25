output "app_url" {
  description = "Public HTTPS entry point (self-signed certificate unless domain_name is set: use curl -k)"
  value       = "https://${local.app_hostname}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "cluster_name" {
  description = "ECS cluster running every service"
  value       = aws_ecs_cluster.main.name
}

output "service_names" {
  description = "ECS service names, for aws ecs describe-services / execute-command"
  value = {
    api-gateway  = aws_ecs_service.api_gateway.name
    inventory    = aws_ecs_service.inventory.name
    billing      = aws_ecs_service.billing.name
    rabbit-queue = aws_ecs_service.rabbit_queue.name
  }
}

output "internal_hostnames" {
  description = "Cloud Map names the services use to reach each other inside the VPC"
  value       = local.service_hostnames
}

output "log_group_name" {
  description = "CloudWatch log group of the app containers"
  value       = aws_cloudwatch_log_group.ecs_logs.name
}

output "cognito_user_pool_id" {
  description = "Cognito user pool that issues API tokens"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito app client to request tokens with"
  value       = aws_cognito_user_pool_client.main.id
}

output "test_user_secret_name" {
  description = "Secrets Manager secret holding the test user's credentials (used by scripts/get-token.sh)"
  value       = aws_secretsmanager_secret.test_user.name
}
