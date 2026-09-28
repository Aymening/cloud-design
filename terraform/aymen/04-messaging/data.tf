# Reads the outputs (subnet ids, rabbitmq security group id) from the
# networking module's state file, same wiring pattern as the databases module.
data "terraform_remote_state" "networking" {
  backend = "local"

  config = {
    path = "${path.module}/../01-networking/terraform.tfstate"
  }
}

locals {
  private_subnet_ids         = data.terraform_remote_state.networking.outputs.private_subnet_ids
  vpc_id                     = data.terraform_remote_state.networking.outputs.vpc_id
  rabbitmq_security_group_id = data.terraform_remote_state.networking.outputs.rabbitmq_security_group_id
}
