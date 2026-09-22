# Private DNS Namespace for internal container resolution (local)
resource "aws_service_discovery_private_dns_namespace" "local" {
  name        = "local"
  description = "Private DNS namespace for internal service discovery"
  vpc         = var.vpc_id
}

# Service Discovery record for inventory-app.local
resource "aws_service_discovery_service" "inventory" {
  name = "inventory-app"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# Service Discovery record for billing-app.local
resource "aws_service_discovery_service" "billing" {
  name = "billing-app"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}