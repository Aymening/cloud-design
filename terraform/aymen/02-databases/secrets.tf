# RDS master passwords cannot contain '/', '@', '"', or a space, so those
# characters are excluded from the generated passwords below.

resource "random_password" "inventory_db" {
  length           = 20
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "billing_db" {
  length           = 20
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# recovery_window_in_days = 0 so destroy + apply can reuse the same secret
# names immediately instead of waiting out the default 30 days.
resource "aws_secretsmanager_secret" "inventory_db" {
  name                    = "${var.project_name}/inventory-db"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-inventory-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "inventory_db" {
  secret_id = aws_secretsmanager_secret.inventory_db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.inventory_db.result
    dbname   = var.inventory_db_name
  })
}

resource "aws_secretsmanager_secret" "billing_db" {
  name                    = "${var.project_name}/billing-db"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-billing-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "billing_db" {
  secret_id = aws_secretsmanager_secret.billing_db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.billing_db.result
    dbname   = var.billing_db_name
  })
}
