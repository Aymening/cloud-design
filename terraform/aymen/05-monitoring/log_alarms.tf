resource "aws_cloudwatch_log_metric_filter" "rabbitmq_errors" {
  name           = "${var.project_name}-rabbitmq-errors"
  log_group_name = local.rabbitmq_log_group_name
  pattern        = "?ERROR ?error ?Error"

  metric_transformation {
    name      = "RabbitmqErrorCount"
    namespace = "${var.project_name}/rabbitmq"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "rabbitmq_errors" {
  alarm_name          = "${var.project_name}-rabbitmq-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.rabbitmq_errors.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.rabbitmq_errors.metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_description   = "rabbit-queue logged at least one error in the last 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
