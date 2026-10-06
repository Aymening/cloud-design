# Target tracking: AWS adds tasks when the metric stays above the target and
# removes them when it stays well below it, between min and max capacity.
# When a service has two policies, it scales out if either one asks to and
# scales in only when both agree.
#
# rabbit-queue is deliberately left out - see services.tf.
locals {
  autoscaled_services = {
    api-gateway = aws_ecs_service.api_gateway.name
    inventory   = aws_ecs_service.inventory.name
    billing     = aws_ecs_service.billing.name
  }
}

resource "aws_appautoscaling_target" "service" {
  for_each = local.autoscaled_services

  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${each.value}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.autoscaling_min_capacity
  max_capacity       = var.autoscaling_max_capacity
}

# CPU policy on every app service.
resource "aws_appautoscaling_policy" "cpu" {
  for_each = aws_appautoscaling_target.service

  name               = "${var.project_name}-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = each.value.service_namespace
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_percent
    scale_out_cooldown = var.scale_out_cooldown_seconds
    scale_in_cooldown  = var.scale_in_cooldown_seconds

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Request-count policy on the gateway: the proxying work is mostly waiting on
# the network, so traffic can rise a lot before CPU does.
resource "aws_appautoscaling_policy" "gateway_requests" {
  name               = "${var.project_name}-api-gateway-requests"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.service["api-gateway"].service_namespace
  resource_id        = aws_appautoscaling_target.service["api-gateway"].resource_id
  scalable_dimension = aws_appautoscaling_target.service["api-gateway"].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.gateway_requests_per_target
    scale_out_cooldown = var.scale_out_cooldown_seconds
    scale_in_cooldown  = var.scale_in_cooldown_seconds

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.api_gateway.arn_suffix}"
    }
  }
}
