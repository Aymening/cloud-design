variable "aws_region" {
  description = "AWS region to create the image repositories in (must match the other modules)"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Name prefix used for every repository (<project_name>/<image>)"
  type        = string
  default     = "cloud-design"
}

variable "images" {
  description = "One repository is created per image. The databases run on RDS, so they have no image here"
  type        = list(string)
  default     = ["api-gateway-app", "inventory-app", "billing-app", "rabbit-queue"]
}

variable "images_to_keep" {
  description = "How many images each repository keeps before the oldest are expired"
  type        = number
  default     = 5
}
