# ECS Cluster definition. Every task runs on Fargate, so there are no EC2
# instances to patch or scale - capacity comes from the services themselves.
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# Centralized CloudWatch log group for the app containers' stdout/stderr
# (rabbit-queue logs to its own group, created in aymen/04-messaging).
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}
