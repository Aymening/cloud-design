# Databases module (Task 2)

Provisions `inventory-db` and `billing-db` as separate RDS PostgreSQL
instances, both private and encrypted.

## What this creates

- 1 DB subnet group, pinned to the private subnets from the networking module
- 2 RDS PostgreSQL instances (`inventory-db`, `billing-db`), each:
  - `db.t4g.micro`, 20 GB storage, encrypted at rest
  - not publicly accessible, reachable only from the `app` security group on 5432
  - a random-generated master password
- 2 Secrets Manager secrets (one per DB) holding username/password/dbname as JSON

## Dependency on the networking module

This module reads `../01-networking`'s state via `terraform_remote_state` to
get the VPC's private subnet IDs and DB security group ID. That means:

```bash
cd ../01-networking && terraform apply -var-file=terraform.tfvars   # first
cd ../02-databases  && terraform apply -var-file=terraform.tfvars   # then this
```

Applying this module before the networking module exists will fail — the
remote state file won't have the outputs yet.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Reading the generated credentials

```bash
aws secretsmanager get-secret-value \
  --secret-id cloud-design/inventory-db \
  --query SecretString --output text
```

## Design notes

- Two separate instances rather than one shared instance: simpler Terraform
  (no manual "create a second database inside the instance" step), and keeps
  `inventory-db`/`billing-db` cleanly isolated per microservice. Costs
  slightly more than one shared instance, but both are the cheapest instance
  class available, so the difference is negligible for this project's scale.
- `skip_final_snapshot = true` and `deletion_protection = false` make
  `terraform destroy` painless during development/testing. Turn both around
  before treating any data here as real.
- `multi_az = false` by default to keep cost down; flip to `true` for a
  standby replica if you want to demonstrate the availability requirement.
