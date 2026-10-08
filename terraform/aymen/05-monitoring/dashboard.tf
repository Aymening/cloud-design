locals {
  # One line per app service on the ECS widgets below.
  ecs_metric = { for name, service in local.service_names : name => ["AWS/ECS", "CPUUtilization", "ClusterName", local.cluster_name, "ServiceName", service] }
  alb        = ["LoadBalancer", local.alb_arn_suffix]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      # Application: traffic and response time through the load balancer
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Requests per minute (load balancer)"
          region  = var.aws_region
          stacked = false
          period  = 60
          metrics = [
            concat(["AWS/ApplicationELB", "RequestCount"], local.alb, [{ stat = "Sum", label = "requests" }]),
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
          title   = "Response time (seconds)"
          region  = var.aws_region
          stacked = false
          period  = 60
          metrics = [
            concat(["AWS/ApplicationELB", "TargetResponseTime"], local.alb, [{ stat = "p95", label = "p95" }]),
            concat(["AWS/ApplicationELB", "TargetResponseTime"], local.alb, [{ stat = "Average", label = "average" }]),
          ]
        }
      },
      # Application: errors and health
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title   = "HTTP errors per minute"
          region  = var.aws_region
          stacked = false
          period  = 60
          metrics = [
            concat(["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count"], local.alb, [{ stat = "Sum", label = "5xx from the app" }]),
            concat(["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count"], local.alb, [{ stat = "Sum", label = "5xx from the load balancer" }]),
            concat(["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count"], local.alb, [{ stat = "Sum", label = "4xx (e.g. no token)" }]),
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title   = "api-gateway targets (load balancer health check)"
          region  = var.aws_region
          stacked = false
          period  = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", local.gateway_target_group_suffix, "LoadBalancer", local.alb_arn_suffix, { stat = "Minimum", label = "healthy" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", local.gateway_target_group_suffix, "LoadBalancer", local.alb_arn_suffix, { stat = "Maximum", label = "unhealthy" }],
          ]
        }
      },
      {
        # ECS reports one CPU sample per running task each minute, so the
        # sample count is the number of running tasks (auto-scaling).
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title   = "Running tasks per service"
          region  = var.aws_region
          stacked = false
          period  = 60
          metrics = [for name, metric in local.ecs_metric : concat(metric, [{ stat = "SampleCount", label = name }])]
        }
      },
      # Application: resource use of each ECS service
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "Service CPU (%)"
          region  = var.aws_region
          stacked = false
          period  = 60
          metrics = [for name, metric in local.ecs_metric : concat(metric, [{ stat = "Average", label = name }])]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "Service memory (%)"
          region  = var.aws_region
          stacked = false
          period  = 60
          metrics = [for name, service in local.service_names : ["AWS/ECS", "MemoryUtilization", "ClusterName", local.cluster_name, "ServiceName", service, { stat = "Average", label = name }]]
        }
      },
      # Application: from the container logs
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "Billing orders saved per minute"
          region = var.aws_region
          view   = "timeSeries"
          query  = "SOURCE '${local.app_log_group_name}' | filter @logStream like /^billing/ and @message like /Order successfully inserted/ | stats count(*) as orders by bin(1m)"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "App errors (latest 50)"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${local.app_log_group_name}' | filter @message like /(?i)(error|exception|traceback)/ | fields @timestamp, @logStream, @message | sort @timestamp desc | limit 50"
        }
      },
      # Databases and queue
      {
        type   = "metric"
        x      = 0
        y      = 24
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
        y      = 24
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
        y      = 30
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
        y      = 30
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
        y      = 36
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
