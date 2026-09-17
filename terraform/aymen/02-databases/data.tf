# Reads the outputs (vpc id, subnet ids, security group ids) from the
# networking module's state file, so we don't have to copy IDs by hand.
data "terraform_remote_state" "networking" {
  backend = "local"

  config = {
    path = "${path.module}/../01-networking/terraform.tfstate"
  }
}

locals {
  private_subnet_ids   = data.terraform_remote_state.networking.outputs.private_subnet_ids
  db_security_group_id = data.terraform_remote_state.networking.outputs.db_security_group_id
}
