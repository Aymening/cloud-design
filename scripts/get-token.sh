#!/bin/bash
# Prints a Cognito access token (valid 60 minutes) for the test user created
# by terraform/houda/platform. The user's password is read from Secrets
# Manager and handed to the AWS CLI through a private temp file (the CLI
# can't read request JSON from a pipe), so it never shows up in the terminal,
# the shell history or the process list.
#
# Usage:
#   TOKEN=$(scripts/get-token.sh)
#   curl -k -H "Authorization: Bearer $TOKEN" "$APP_URL/api/movies"
set -euo pipefail
cd "$(dirname "$0")/.."

secret_name=$(terraform -chdir=terraform/houda/platform output -raw test_user_secret_name)

request_file=$(mktemp) # created with mode 600: only you can read it
trap 'rm -f "$request_file"' EXIT

aws secretsmanager get-secret-value --secret-id "$secret_name" --query SecretString --output text |
  python3 -c '
import json, sys
secret = json.load(sys.stdin)
print(json.dumps({
    "AuthFlow": "USER_PASSWORD_AUTH",
    "ClientId": secret["client_id"],
    "AuthParameters": {"USERNAME": secret["username"], "PASSWORD": secret["password"]},
}))' >"$request_file"

aws cognito-idp initiate-auth --cli-input-json "file://$request_file" \
  --query AuthenticationResult.AccessToken --output text
