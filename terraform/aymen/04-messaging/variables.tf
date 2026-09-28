variable "aws_region" {
  description = "AWS region to deploy the messaging resources into (must match the networking module)"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Name prefix used to tag and name all messaging resources"
  type        = string
  default     = "cloud-design"
}

variable "rabbitmq_username" {
  description = "RabbitMQ username (must not be 'guest' - the entrypoint script rejects it)"
  type        = string
  default     = "app_user"
}

variable "rabbitmq_queue" {
  description = "Name of the durable queue billing-app consumes from and api-gateway-app publishes to"
  type        = string
  default     = "billing_queue"
}

variable "cpu" {
  description = "Fargate task CPU units for rabbit-queue"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory (MB) for rabbit-queue"
  type        = number
  default     = 512
}

variable "container_image" {
  description = "Image URI for the rabbit-queue container (set once it's pushed to ECR in task 6)"
  type        = string
  default     = "rabbit-queue:latest"
}
