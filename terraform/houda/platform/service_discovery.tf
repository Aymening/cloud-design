# Private DNS namespace for internal service discovery (Cloud Map). Each ECS
# service below registers its tasks' IPs under <name>.local; ECS adds and
# removes records as tasks start, stop or fail their health check, so the
# names keep working while auto-scaling changes the number of tasks.
resource "aws_service_discovery_private_dns_namespace" "local" {
  name        = "local"
  description = "Private DNS namespace for internal service discovery"
  vpc         = local.vpc_id
}

locals {
  discovered_services = ["inventory-app", "billing-app", "rabbit-queue"]
}

resource "aws_service_discovery_service" "this" {
  for_each = toset(local.discovered_services)

  name = each.key

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.local.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
