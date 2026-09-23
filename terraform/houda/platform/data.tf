# Reads the outputs of the other modules from their local state files, the
# same wiring pattern the aymen/ modules use between themselves - no IDs are
# copied by hand. Those modules must be applied before this one.
data "terraform_remote_state" "networking" {
  backend = "local"

  config = {
    path = "${path.module}/../../aymen/01-networking/terraform.tfstate"
  }
}

data "terraform_remote_state" "databases" {
  backend = "local"

  config = {
    path = "${path.module}/../../aymen/02-databases/terraform.tfstate"
  }
}

data "terraform_remote_state" "messaging" {
  backend = "local"

  config = {
    path = "${path.module}/../../aymen/04-messaging/terraform.tfstate"
  }
}

data "terraform_remote_state" "ecr" {
  backend = "local"

  config = {
    path = "${path.module}/../ecr/terraform.tfstate"
  }
}

locals {
  networking = data.terraform_remote_state.networking.outputs
  databases  = data.terraform_remote_state.databases.outputs
  messaging  = data.terraform_remote_state.messaging.outputs
  ecr        = data.terraform_remote_state.ecr.outputs

  vpc_id                     = local.networking.vpc_id
  public_subnet_ids          = local.networking.public_subnet_ids
  private_subnet_ids         = local.networking.private_subnet_ids
  alb_security_group_id      = local.networking.alb_security_group_id
  app_security_group_id      = local.networking.app_security_group_id
  rabbitmq_security_group_id = local.networking.rabbitmq_security_group_id

  # RDS endpoints come back as "host:port".
  inventory_db_host = split(":", local.databases.inventory_db_endpoint)[0]
  billing_db_host   = split(":", local.databases.billing_db_endpoint)[0]

  # Secrets created by aymen/: the DB ones hold {username, password, dbname},
  # the RabbitMQ one holds {username, password, queue}.
  inventory_db_secret_arn = local.databases.inventory_db_secret_arn
  billing_db_secret_arn   = local.databases.billing_db_secret_arn
  rabbitmq_secret_arn     = local.messaging.rabbitmq_secret_arn

  images = {
    for name, url in local.ecr.repository_urls : name => "${url}:${var.image_tag}"
  }
}
