variable "aws_region" {
  description = "AWS region to deploy the monitoring resources into (must match the other modules)"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Name prefix used to tag and name all monitoring resources"
  type        = string
  default     = "cloud-design"
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}

variable "db_cpu_threshold_percent" {
  description = "RDS CPU utilization percent that triggers an alarm"
  type        = number
  default     = 80
}

variable "db_free_storage_threshold_bytes" {
  description = "RDS free storage space (bytes) below which an alarm fires"
  type        = number
  default     = 2000000000 # 2 GB
}

variable "db_connections_threshold" {
  description = "RDS connection count that triggers an alarm"
  type        = number
  default     = 50
}

variable "app_5xx_threshold" {
  description = "Number of 5xx responses from the app in 5 minutes that triggers an alarm"
  type        = number
  default     = 10
}
