output "inventory_db_endpoint" {
  description = "Connection endpoint (host:port) for the inventory database"
  value       = aws_db_instance.inventory_db.endpoint
}

output "billing_db_endpoint" {
  description = "Connection endpoint (host:port) for the billing database"
  value       = aws_db_instance.billing_db.endpoint
}

output "inventory_db_secret_arn" {
  description = "Secrets Manager ARN holding the inventory-db username/password/dbname"
  value       = aws_secretsmanager_secret.inventory_db.arn
}

output "billing_db_secret_arn" {
  description = "Secrets Manager ARN holding the billing-db username/password/dbname"
  value       = aws_secretsmanager_secret.billing_db.arn
}

output "inventory_db_identifier" {
  description = "RDS instance identifier for inventory-db (needed for CloudWatch alarm dimensions)"
  value       = aws_db_instance.inventory_db.id
}

output "billing_db_identifier" {
  description = "RDS instance identifier for billing-db (needed for CloudWatch alarm dimensions)"
  value       = aws_db_instance.billing_db.id
}
