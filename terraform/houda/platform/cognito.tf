# -----------------------------------------------------------------------------
# ACM Certificate for SSL/TLS
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "app_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "app-acm-certificate"
  }
}

# -----------------------------------------------------------------------------
# Cognito User Pool and Client
# -----------------------------------------------------------------------------
resource "aws_cognito_user_pool" "main" {
  name = "app-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "app-user-pool-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret     = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

# -----------------------------------------------------------------------------
# Secrets Manager for Database Credentials
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "app/production/db-credentials"
  description = "Database credentials for the application"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "db_user"
    password = "ReplaceWithSecurePassword123!"
    engine   = "postgres"
    host     = "db.local"
    port     = 5432
    dbname   = "appdb"
  })
}

# -----------------------------------------------------------------------------
# Scoped IAM Execution Role for ECS
# -----------------------------------------------------------------------------

# Attachment for default AWS managed policy (ECR pull & CloudWatch logging)
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Scoped Inline Policy for Secrets Manager Access
resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "ecs-secrets-policy"
  description = "Allows ECS tasks to read database secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}