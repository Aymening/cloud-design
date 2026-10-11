# Reads the outputs (subnet ids, rabbitmq security group id) from the
# networking module's state file, same wiring pattern as the databases module.
data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = "cloud-design-tfstate-008871758028"
    key    = "aymen/01-networking/terraform.tfstate"
    region = "eu-west-3"
  }
}

locals {
  private_subnet_ids         = data.terraform_remote_state.networking.outputs.private_subnet_ids
  vpc_id                     = data.terraform_remote_state.networking.outputs.vpc_id
  rabbitmq_security_group_id = data.terraform_remote_state.networking.outputs.rabbitmq_security_group_id
}
