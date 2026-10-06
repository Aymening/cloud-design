variable "aws_region" {
  description = "AWS region to deploy into (must match the aymen/ and ecr modules)"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Name prefix used to tag and name all platform resources"
  type        = string
  default     = "cloud-design"
}

variable "image_tag" {
  description = "Tag of the images pushed to ECR by scripts/push-images.sh"
  type        = string
  default     = "latest"
}

# -----------------------------------------------------------------------------
# Task sizing
# -----------------------------------------------------------------------------
variable "task_cpu" {
  description = "Fargate CPU units per app task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate memory (MB) per app task"
  type        = number
  default     = 512
}

# -----------------------------------------------------------------------------
# Auto-scaling (task 9) - tune these from the load test results
# -----------------------------------------------------------------------------
variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks per app service"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks per app service"
  type        = number
  default     = 4
}

variable "cpu_target_percent" {
  description = "Average service CPU the target-tracking policy tries to hold"
  type        = number
  default     = 60
}

variable "gateway_requests_per_target" {
  description = "Requests per minute per api-gateway task before scaling out (ALBRequestCountPerTarget)"
  type        = number
  default     = 600
}

variable "scale_out_cooldown_seconds" {
  description = "Wait after a scale-out before scaling out again"
  type        = number
  default     = 60
}

variable "scale_in_cooldown_seconds" {
  description = "Wait after a scale-in before scaling in again"
  type        = number
  default     = 180
}

# -----------------------------------------------------------------------------
# HTTPS (task 8)
# -----------------------------------------------------------------------------
variable "domain_name" {
  description = "Domain to serve the app on (e.g. app.example.com). Leave null to use a self-signed certificate on the load balancer's own DNS name"
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Route 53 public hosted zone that owns domain_name; needed to validate the ACM certificate. Leave null with domain_name"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Cognito (task 8)
# -----------------------------------------------------------------------------
variable "test_user_email" {
  description = "Email of the Cognito user created for smoke and load tests (no email is ever sent to it)"
  type        = string
  default     = "loadtest@example.com"
}
