variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the ECS services will be deployed"
  type        = string
  default     = "vpc-0123456789abcdef0" # REPLACE THIS
}

variable "private_subnet_ids" {
  description = "Private Subnets for running ECS Fargate tasks securely"
  type        = list(string)
  default     = ["subnet-01111111111111111", "subnet-02222222222222222"] # REPLACE THIS
}

variable "ecs_security_group_id" {
  description = "Security Group ID allowing inbound traffic on required ports (3000, 8080)"
  type        = string
  default     = "sg-0123456789abcdef0" # REPLACE THIS
}

variable "api_gateway_image" {
  description = "Docker image for api-gateway-app"
  type        = string
  default     = "nginx:alpine" # REPLACE THIS WITH YOUR ECR / DOCKER HUB IMAGE
}

variable "inventory_app_image" {
  description = "Docker image for inventory-app"
  type        = string
  default     = "nginx:alpine" # REPLACE THIS WITH YOUR ECR / DOCKER HUB IMAGE
}

variable "billing_app_image" {
  description = "Docker image for billing-app"
  type        = string
  default     = "nginx:alpine" # REPLACE THIS WITH YOUR ECR / DOCKER HUB IMAGE
}