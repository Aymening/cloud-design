# Networking module (Task 1)

Provisions the VPC and everything the rest of the project's AWS
resources (databases, containers, load balancer) will attach to.

## What this creates

- 1 VPC (`10.0.0.0/16` by default)
- 2 public subnets and 2 private subnets, spread across 2 availability zones
- 1 Internet Gateway, with a route table sending public subnet traffic to it
- 1 NAT Gateway (in the first public subnet), with a route table sending
  private subnet traffic to it — so private resources can reach the
  internet outbound without being reachable from it inbound
- 4 security groups, each only trusting the tier in front of it:
  - `alb`: accepts 80/443 from the internet
  - `app`: accepts 3000 (api-gateway-app) from `alb` only. inventory-app and
    billing-app (8080) are reached through the `services-internal` group
    created in `terraform/houda/platform`
  - `db`: accepts 5432 (Postgres) from `app` only
  - `rabbitmq`: accepts 5672 (AMQP) from `app` only

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars if needed

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Outputs

Other modules (databases, ECS/EKS cluster, load balancer, auto-scaling)
consume `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, and the
security group ids exposed in `outputs.tf` to attach their own resources
to this network.

## Design notes

- A single NAT Gateway is shared by both private subnets rather than one
  per AZ — cheaper, at the cost of a shared failure point for outbound
  internet access if that AZ goes down. Acceptable tradeoff for this
  project's scale.
- Databases and app services are never placed in a public subnet, so
  they're unreachable from the internet regardless of security group
  rules — satisfying the "private resources only accessible from the
  VPC" requirement at the network layer, not just the firewall layer.
