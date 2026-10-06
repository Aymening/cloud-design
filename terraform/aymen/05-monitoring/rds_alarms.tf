locals {
  db_instances = {
    inventory = local.inventory_db_identifier
    billing   = local.billing_db_identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  for_each = local.db_instances

  alarm_name          = "${var.project_name}-${each.key}-db-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.db_cpu_threshold_percent
  alarm_description   = "${each.key}-db CPU above ${var.db_cpu_threshold_percent}% for 3 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = each.value
  }
}

resource "aws_cloudwatch_metric_alarm" "db_free_storage" {
  for_each = local.db_instances

  alarm_name          = "${var.project_name}-${each.key}-db-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.db_free_storage_threshold_bytes
  alarm_description   = "${each.key}-db free storage below ${var.db_free_storage_threshold_bytes} bytes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = each.value
  }
}

resource "aws_cloudwatch_metric_alarm" "db_connections" {
  for_each = local.db_instances

  alarm_name          = "${var.project_name}-${each.key}-db-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.db_connections_threshold
  alarm_description   = "${each.key}-db connection count above ${var.db_connections_threshold} for 3 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = each.value
  }
}
