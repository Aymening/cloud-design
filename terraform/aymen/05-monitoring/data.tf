# Reads outputs from the databases and messaging modules so alarms can
# target the real RDS instances and log group without duplicating them.
data "terraform_remote_state" "databases" {
  backend = "s3"
  config = {
    bucket = "cloud-design-tfstate-008871758028"
    key    = "aymen/02-databases/terraform.tfstate"
    region = "eu-west-3"
  }
}

data "terraform_remote_state" "messaging" {
  backend = "s3"
  config = {
    bucket = "cloud-design-tfstate-008871758028"
    key    = "aymen/04-messaging/terraform.tfstate"
    region = "eu-west-3"
  }
}

# The platform module (ECS cluster, services, load balancer) gives the app
# metrics shown on the dashboard and used by app_alarms.tf.
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "cloud-design-tfstate-008871758028"
    key    = "houda/platform/terraform.tfstate"
    region = "eu-west-3"
  }
}

locals {
  inventory_db_identifier = data.terraform_remote_state.databases.outputs.inventory_db_identifier
  billing_db_identifier   = data.terraform_remote_state.databases.outputs.billing_db_identifier
  rabbitmq_log_group_name = data.terraform_remote_state.messaging.outputs.log_group_name

  cluster_name                = data.terraform_remote_state.platform.outputs.cluster_name
  service_names               = data.terraform_remote_state.platform.outputs.service_names
  app_log_group_name          = data.terraform_remote_state.platform.outputs.log_group_name
  alb_arn_suffix              = data.terraform_remote_state.platform.outputs.alb_arn_suffix
  gateway_target_group_suffix = data.terraform_remote_state.platform.outputs.api_gateway_target_group_arn_suffix
}
