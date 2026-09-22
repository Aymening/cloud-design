variable "aws_region" {
  type        = string
  description = "The AWS region where resources will be deployed"
  default     = "us-east-1"
}

# Network Variables (Provided by Teammate)
variable "vpc_id" {
  type        = string
  description = "VPC ID where the ECS services and ALB will be deployed"
  default     = "vpc-xxxxxx" # REPLACE WITH TEAMMATE'S VPC ID
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public Subnet IDs for the Application Load Balancer"
  default     = ["subnet-pub1xxxx", "subnet-pub2xxxx"] # REPLACE WITH TEAMMATE'S PUBLIC SUBNETS
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private Subnet IDs for ECS tasks"
  default     = ["subnet-priv1xxxx", "subnet-priv2xxxx"] # REPLACE WITH TEAMMATE'S PRIVATE SUBNETS
}

# Security Group Variables (Provided by Teammate)
variable "alb_security_group_id" {
  type        = string
  description = "Security group ID for the ALB allowing public access on port 80/443"
  default     = "sg-albxxxx" # REPLACE WITH TEAMMATE'S ALB SECURITY GROUP ID
}

variable "ecs_security_group_id" {
  type        = string
  description = "Security group ID for ECS tasks"
  default     = "sg-ecsxxxx" # REPLACE WITH TEAMMATE'S ECS SECURITY GROUP ID
}

# Container Image URIs
variable "api_gateway_image" {
  type        = string
  description = "ECR image URI for api-gateway-app (Port 3000)"
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/api-gateway-app:latest"
}

variable "inventory_app_image" {
  type        = string
  description = "ECR image URI for inventory-app (Port 8080)"
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/inventory-app:latest"
}

variable "billing_app_image" {
  type        = string
  description = "ECR image URI for billing-app (Port 8080)"
  default     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/billing-app:latest"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the ACM SSL Certificate"
  default     = "example.com" # Replace with your actual domain name
}