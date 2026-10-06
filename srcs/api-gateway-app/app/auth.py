import os

import jwt
from flask import jsonify, request


def required_environment(name):
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required Gateway configuration: {name}")
    return value


# Both are required: the gateway refuses to start without them rather than
# serving /api/* without authentication.
COGNITO_USER_POOL_ID = required_environment("COGNITO_USER_POOL_ID")
COGNITO_CLIENT_ID = required_environment("COGNITO_CLIENT_ID")

_region = COGNITO_USER_POOL_ID.split("_", 1)[0]
_issuer = f"https://cognito-idp.{_region}.amazonaws.com/{COGNITO_USER_POOL_ID}"
# The signing keys are fetched once and cached, not on every request.
_jwks_client = jwt.PyJWKClient(f"{_issuer}/.well-known/jwks.json")


def unauthorized(message):
    response = jsonify({"error": message})
    response.headers["WWW-Authenticate"] = "Bearer"
    return response, 401


def require_cognito_token():
    """Reject /api/* requests that don't carry a valid Cognito access token.

    Runs before every request; returning a response stops the request there.
    """
    if not request.path.startswith("/api/"):
        return None

    scheme, _, token = request.headers.get("Authorization", "").partition(" ")
    if scheme.lower() != "bearer" or not token:
        return unauthorized("Missing bearer token")

    try:
        signing_key = _jwks_client.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            issuer=_issuer,
            options={"require": ["exp", "iss", "token_use", "client_id"]},
        )
    except jwt.PyJWKClientConnectionError:
        return jsonify({"error": "Authentication service unavailable"}), 503
    except jwt.PyJWTError:
        return unauthorized("Invalid or expired token")

    # Cognito access tokens carry the app client in "client_id" (they have no
    # "aud"); ID tokens are rejected so only the API client's tokens work.
    if claims["token_use"] != "access" or claims["client_id"] != COGNITO_CLIENT_ID:
        return unauthorized("Invalid or expired token")

    return None
