resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "RDS CPU Utilization (%)"
          region  = var.aws_region
          stacked = false
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", local.inventory_db_identifier, { label = "inventory-db" }],
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", local.billing_db_identifier, { label = "billing-db" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "RDS Free Storage Space (bytes)"
          region  = var.aws_region
          stacked = false
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", local.inventory_db_identifier, { label = "inventory-db" }],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", local.billing_db_identifier, { label = "billing-db" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "RDS Database Connections"
          region  = var.aws_region
          stacked = false
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", local.inventory_db_identifier, { label = "inventory-db" }],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", local.billing_db_identifier, { label = "billing-db" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "rabbit-queue Error Count"
          region  = var.aws_region
          stacked = false
          metrics = [
            [aws_cloudwatch_log_metric_filter.rabbitmq_errors.metric_transformation[0].namespace, aws_cloudwatch_log_metric_filter.rabbitmq_errors.metric_transformation[0].name],
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "rabbit-queue recent logs"
          region = var.aws_region
          query  = "SOURCE '${local.rabbitmq_log_group_name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
        }
      },
    ]
  })
}
