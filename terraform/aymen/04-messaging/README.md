# Messaging module (Task 4)

Provisions everything `rabbit-queue` needs that doesn't depend on the ECS
cluster existing yet: persistent storage, credentials, and a ready-to-run
task definition. See [TOPOLOGY.md](./TOPOLOGY.md) for the actual queue
topology (single durable queue, default exchange, manual ack/nack).

## What this creates

- 1 EFS file system + mount targets (one per private subnet) + access point,
  so `/var/lib/rabbitmq` survives an ECS task being replaced, not just a
  broker restart
- 1 Secrets Manager secret with a random-generated RabbitMQ password
- 1 IAM role for ECS task execution (image pull, logs, reading the secret)
- 1 CloudWatch log group
- 1 Fargate task definition (`rabbit-queue`), wired to the EFS volume and
  the secret

## What this does NOT create

- No `aws_ecs_service` and no ECS cluster - registering this task
  definition against a running cluster is task 6's job. This module only
  needs the networking module (VPC/subnets/security groups) to apply; it
  doesn't need the cluster to exist yet, since IAM roles and task
  definitions aren't tied to any specific cluster.
- No image repository - the `rabbit-queue` image is pushed to the ECR
  repository from `terraform/houda/ecr` and passed in with
  `-var "container_image=..."` (step 4 of the main README's Deploying
  section).

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Verifying message consumption locally (not AWS - see scripts/)

Before any of this touches AWS, `scripts/test-billing-consumer.sh` (repo
root) proves the actual application logic works: it publishes a message onto
`billing_queue` the same way `api-gateway-app` does, then checks that
`billing-app` consumed it and wrote the row to `billing-db`. Run it with:

```bash
cp .env.example .env   # first time only
./scripts/test-billing-consumer.sh
```
