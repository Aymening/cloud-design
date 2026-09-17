resource "aws_db_instance" "billing_db" {
  identifier     = "${var.project_name}-billing-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.billing_db_name
  username = var.db_username
  password = random_password.billing_db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [local.db_security_group_id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-billing-db"
  }
}
