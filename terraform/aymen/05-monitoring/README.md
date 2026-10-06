# Monitoring module (Task 5)

Alarms and a dashboard for what already exists (RDS, RabbitMQ) without
duplicating or depending on the ECS cluster Houda builds in task 6.

## What this creates

- 1 SNS topic + email subscription for alarm notifications
- 9 CloudWatch alarms:
  - CPU, free storage, and connection count for both `inventory-db` and
    `billing-db` (6 alarms)
  - a log-based alarm that fires when `rabbit-queue` logs an error (1 alarm,
    backed by a log metric filter)
- 1 CloudWatch dashboard (`${project_name}-overview`) with RDS CPU/storage/
  connections charts, the rabbit-queue error count, and a live tail of
  rabbit-queue's recent logs

## Dependencies

Reads state from the databases module (RDS instance identifiers) and the
messaging module (the rabbit-queue CloudWatch log group), so both need to
be applied first:

```bash
cd ../02-databases && terraform apply -var-file=terraform.tfvars
cd ../04-messaging  && terraform apply -var-file=terraform.tfvars
cd ../05-monitoring && terraform apply -var-file=terraform.tfvars
```

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# set alert_email to a real address you can check

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

After `apply`, AWS emails `alert_email` a subscription confirmation link -
alarms stay silent for that address until it's clicked.

## What's deferred to task 6

Once Houda's ECS cluster exists and runs `inventory-app`, `billing-app`,
`api-gateway-app`, and `rabbit-queue` as actual services, this module should
grow ECS-level alarms too (service CPU/memory, running task count dropping
to 0). Not added yet since those services don't exist to alarm on.
