# aymen/01-networking's app security group only accepts traffic from the load
# balancer, so api-gateway-app could not reach inventory-app on 8080. Adding a
# rule to that group from here would be wiped on the next apply of the
# networking module (it defines its rules inline), so the app services also
# join this second group, which only lets its own members talk to each other.
resource "aws_security_group" "services_internal" {
  name        = "${var.project_name}-services-internal-sg"
  description = "Service-to-service traffic between the app tasks"
  vpc_id      = local.vpc_id

  ingress {
    description = "App port from other app tasks"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-services-internal-sg"
  }
}
