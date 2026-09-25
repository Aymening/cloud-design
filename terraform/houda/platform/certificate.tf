# The HTTPS listener needs an issued certificate. An ACM certificate for a
# real domain is only issued once its DNS validation record exists, so there
# are two paths:
#   - domain_name + route53_zone_id set: public ACM certificate, validated
#     automatically through Route 53, plus an alias record to the ALB
#   - otherwise: a self-signed certificate imported into ACM. Traffic is still
#     encrypted, but clients must skip verification (curl -k)
locals {
  use_custom_domain = var.domain_name != null && var.route53_zone_id != null

  certificate_arn = (local.use_custom_domain
    ? aws_acm_certificate_validation.custom[0].certificate_arn
    : aws_acm_certificate.self_signed[0].arn
  )
  app_hostname = local.use_custom_domain ? var.domain_name : aws_lb.main.dns_name
}

# -----------------------------------------------------------------------------
# Custom domain
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "custom" {
  count = local.use_custom_domain ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-certificate"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = local.use_custom_domain ? {
    for dvo in aws_acm_certificate.custom[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "custom" {
  count = local.use_custom_domain ? 1 : 0

  certificate_arn         = aws_acm_certificate.custom[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "app" {
  count = local.use_custom_domain ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# -----------------------------------------------------------------------------
# Self-signed fallback
# -----------------------------------------------------------------------------
# The private key ends up in the Terraform state, which is git-ignored and
# stays on the machine that runs apply.
resource "tls_private_key" "self_signed" {
  count = local.use_custom_domain ? 0 : 1

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  count = local.use_custom_domain ? 0 : 1

  private_key_pem       = tls_private_key.self_signed[0].private_key_pem
  validity_period_hours = 24 * 365

  subject {
    common_name  = "${var.project_name}.local"
    organization = var.project_name
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "self_signed" {
  count = local.use_custom_domain ? 0 : 1

  private_key      = tls_private_key.self_signed[0].private_key_pem
  certificate_body = tls_self_signed_cert.self_signed[0].cert_pem

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-self-signed-certificate"
  }
}
