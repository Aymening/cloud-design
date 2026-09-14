output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "Security group ID for the load balancer"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group ID for app services (inventory-app, billing-app, api-gateway-app)"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security group ID for the databases (inventory-db, billing-db)"
  value       = aws_security_group.db.id
}

output "rabbitmq_security_group_id" {
  description = "Security group ID for rabbit-queue"
  value       = aws_security_group.rabbitmq.id
}
