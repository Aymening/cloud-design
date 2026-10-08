# Health alarms for the app itself (load balancer and ECS services). They
# email the same SNS topic as the database alarms.

resource "aws_cloudwatch_metric_alarm" "gateway_no_healthy_tasks" {
  alarm_name          = "${var.project_name}-api-gateway-no-healthy-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_description   = "No healthy api-gateway task behind the load balancer for 2 minutes: the API is down"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = local.gateway_target_group_suffix
    LoadBalancer = local.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "app_5xx" {
  alarm_name          = "${var.project_name}-app-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.app_5xx_threshold
  treat_missing_data  = "notBreaching"
  alarm_description   = "More than ${var.app_5xx_threshold} server errors (5xx) from the app in 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = local.alb_arn_suffix
  }
}

# ECS reports one CPU sample per running task each minute: no samples means
# the service has no running task. The data arrives 1-2 minutes late, so the
# alarm waits for 3 empty minutes in a row.
resource "aws_cloudwatch_metric_alarm" "service_not_running" {
  for_each = local.service_names

  alarm_name          = "${var.project_name}-${each.key}-not-running"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "SampleCount"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_description   = "${each.key} has had no running task for 3 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = local.cluster_name
    ServiceName = each.value
  }
}
