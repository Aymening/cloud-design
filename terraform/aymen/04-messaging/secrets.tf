# RABBITMQ_USER must not be "guest" - the entrypoint script rejects it -
# which is why it's a variable with a non-guest default rather than generated.
resource "random_password" "rabbitmq" {
  length           = 20
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# recovery_window_in_days = 0 so destroy + apply can reuse the same secret
# name immediately instead of waiting out the default 30 days.
resource "aws_secretsmanager_secret" "rabbitmq" {
  name                    = "${var.project_name}/rabbit-queue"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-rabbit-queue-secret"
  }
}

resource "aws_secretsmanager_secret_version" "rabbitmq" {
  secret_id = aws_secretsmanager_secret.rabbitmq.id
  secret_string = jsonencode({
    username = var.rabbitmq_username
    password = random_password.rabbitmq.result
    queue    = var.rabbitmq_queue
  })
}
