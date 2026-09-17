variable "aws_region" {
  description = "AWS region to deploy the database resources into (must match the networking module)"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Name prefix used to tag and name all database resources"
  type        = string
  default     = "cloud-design"
}

variable "engine_version" {
  description = "PostgreSQL engine version for both databases"
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "RDS instance size. db.t4g.micro is the cheapest option suitable for this project's scale"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Storage size in GB for each database instance"
  type        = number
  default     = 20
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "multi_az" {
  description = "Whether to run a standby replica in a second AZ (higher availability, roughly doubles cost)"
  type        = bool
  default     = false
}

variable "inventory_db_name" {
  description = "Database name for the inventory service"
  type        = string
  default     = "movies_db"
}

variable "billing_db_name" {
  description = "Database name for the billing service"
  type        = string
  default     = "billing_db"
}

variable "db_username" {
  description = "Master username for both database instances"
  type        = string
  default     = "appuser"
}
