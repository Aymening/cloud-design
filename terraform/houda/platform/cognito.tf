# Cognito issues the tokens that protect the public /api/* endpoints.
# api-gateway-app verifies them itself (signature, expiry, issuer, client id)
# before proxying; /health stays open for the load balancer's health checks.
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

# Public client (no secret): tokens are fetched from the CLI or scripts with
# USER_PASSWORD_AUTH, see scripts/get-token.sh.
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-api-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  prevent_user_existence_errors = "ENABLED"
  access_token_validity         = 60
  id_token_validity             = 60
  refresh_token_validity        = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# -----------------------------------------------------------------------------
# Test user for smoke and load tests
# -----------------------------------------------------------------------------
# The password is generated, never written in the repo, and handed out only
# through Secrets Manager.
resource "random_password" "test_user" {
  length           = 20
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!#%*()-_=+[]{}:?"
}

resource "aws_cognito_user" "test" {
  user_pool_id   = aws_cognito_user_pool.main.id
  username       = var.test_user_email
  password       = random_password.test_user.result
  message_action = "SUPPRESS"

  attributes = {
    email          = var.test_user_email
    email_verified = "true"
  }
}

# recovery_window_in_days = 0 so destroy + apply during testing can reuse the
# same secret name immediately instead of waiting out the default 30 days.
resource "aws_secretsmanager_secret" "test_user" {
  name                    = "${var.project_name}/cognito-test-user"
  description             = "Credentials of the Cognito test user used by scripts/get-token.sh"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "test_user" {
  secret_id = aws_secretsmanager_secret.test_user.id
  secret_string = jsonencode({
    username  = var.test_user_email
    password  = random_password.test_user.result
    client_id = aws_cognito_user_pool_client.main.id
  })
}
