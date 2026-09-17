# skip_final_snapshot and deletion_protection are both off here so this
# project's databases can be torn down cleanly during testing. Flip both
# to true/false-off before anything resembling production data goes in.
resource "aws_db_instance" "inventory_db" {
  identifier     = "${var.project_name}-inventory-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.inventory_db_name
  username = var.db_username
  password = random_password.inventory_db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [local.db_security_group_id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-inventory-db"
  }
}
