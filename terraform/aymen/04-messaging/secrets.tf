# RABBITMQ_USER must not be "guest" - the entrypoint script rejects it -
# which is why it's a variable with a non-guest default rather than generated.
resource "random_password" "rabbitmq" {
  length           = 20
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "rabbitmq" {
  name = "${var.project_name}/rabbit-queue"

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
