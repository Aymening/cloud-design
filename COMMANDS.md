# Commands

The commands of this project, step by step. The architecture, the design
decisions and the configuration are described in [README.md](README.md).

| Part | What you find there |
|------|---------------------|
| [1. Use AWS step by step](#1-use-aws-step-by-step) | From installing the tools to deleting everything, with a check after each step |
| [2. Audit commands](#2-audit-commands) | The commands for each audit question, with the expected result, and the Postman collection |
| [3. What every file does](#3-what-every-file-does) | Every file in the repository |

## 1. Use AWS step by step

Everything runs in the region `eu-west-3` (Paris). Run the commands from the
repository root (the `cloud-design` folder), unless a `cd` says otherwise.

### Step 1. Install the tools

| Tool | Used for | Check it works |
|------|----------|----------------|
| AWS CLI v2 | Talking to AWS from the terminal | `aws --version` |
| Terraform 1.5 or newer | Creating the AWS resources described in the `.tf` files | `terraform version` |
| Docker or Podman | Building the images, running the project locally | `docker --version` |
| git, curl, Python 3 | Getting the code, calling the API, small scripts | `git --version` |

On macOS, with Homebrew (Docker: install Docker Desktop):

```bash
brew install awscli
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

On Linux, without root (`~/.local/bin` must be in your `PATH`):

```bash
mkdir -p ~/.local/bin

# AWS CLI
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install --install-dir ~/.local/aws-cli --bin-dir ~/.local/bin

# Terraform (newest version: https://developer.hashicorp.com/terraform/install)
curl -fsSL https://releases.hashicorp.com/terraform/1.16.3/terraform_1.16.3_linux_amd64.zip -o terraform.zip
unzip -o terraform.zip terraform -d ~/.local/bin
```

### Step 2. Connect the AWS CLI to your account

1. In the AWS console, open **IAM → Users → Create user** (this project
   used `cloud-design-deploy`) and attach the `AdministratorAccess` policy.
2. Open the user, then **Security credentials → Create access key →
   Command Line Interface (CLI)**. Copy the access key ID and the secret
   access key: the secret is shown only once.
3. In the terminal:

```bash
aws configure
#   AWS Access Key ID [None]:      your access key ID
#   AWS Secret Access Key [None]:  your secret access key
#   Default region name [None]:    eu-west-3
#   Default output format [None]:  json

aws sts get-caller-identity    # your account ID and user: the CLI works
aws configure list             # where the CLI takes its settings from
```

`aws configure` stores the keys in `~/.aws/credentials`, outside the
project. Never put them in the repository.

### Step 3. Get the code

```bash
git clone https://github.com/Aymening/cloud-design.git
cd cloud-design

git pull    # later, to get the newest changes
```

### Step 4. Prepare the settings

Each Terraform module reads its settings from a `terraform.tfvars` file,
which git ignores. Create them from the examples:

```bash
for m in terraform/aymen/01-networking terraform/aymen/02-databases terraform/aymen/04-messaging \
         terraform/aymen/05-monitoring terraform/houda/ecr terraform/houda/platform; do
  [ -f $m/terraform.tfvars ] || cp $m/terraform.tfvars.example $m/terraform.tfvars
done
```

Then open `terraform/aymen/05-monitoring/terraform.tfvars` and put your email
in `alert_email`: it receives the alarms. The other default values work as
they are; README.md, section 4, describes them.

### Step 5. Create the infrastructure

Terraform works in three commands, run in each module's folder:

- `terraform init`: once per module, downloads the AWS provider
- `terraform plan`: shows what would be created, changed or destroyed, and changes nothing
- `terraform apply`: shows the plan again and makes the changes after you type `yes`

The modules use each other's results, so apply them in this order. The
Terraform state files (what Terraform created) stay in the module folders:
keep them, Terraform needs them for every later change.

#### 5.1 Network

```bash
cd terraform/aymen/01-networking
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
cd ../../..

aws ec2 describe-vpcs --filters Name=tag:Name,Values=cloud-design-vpc \
  --query 'Vpcs[].[VpcId,CidrBlock]' --output table
```

Creates the VPC, 2 public and 2 private subnets, the internet gateway, the
NAT gateway, the route tables and the security groups.

#### 5.2 Databases

```bash
cd terraform/aymen/02-databases
terraform init && terraform apply -var-file=terraform.tfvars
cd ../../..

aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus]' --output table
```

Creates the two RDS PostgreSQL databases and their passwords in Secrets
Manager. This is the slowest step (about 5 to 10 minutes): the databases are
ready when their status is `available`.

#### 5.3 Image registry, then the images

```bash
cd terraform/houda/ecr
terraform init && terraform apply -var-file=terraform.tfvars
cd ../../..

scripts/push-images.sh    # logs in to ECR, builds the 4 images, pushes them
aws ecr describe-repositories --query 'repositories[].repositoryName' --output table
```

Creates the 4 ECR repositories and turns on Amazon Inspector scanning, then
builds and pushes the images.

#### 5.4 RabbitMQ

```bash
cd terraform/aymen/04-messaging
terraform init
terraform apply -var-file=terraform.tfvars \
  -var "container_image=$(terraform -chdir=../../houda/ecr output -raw rabbit_queue_image)"
cd ../../..

aws efs describe-file-systems --query 'FileSystems[].[Name,LifeCycleState,Encrypted]' --output table
```

Creates RabbitMQ's task definition, its EFS storage, its secret, its IAM
roles and its log group. The `-var` part gives it the image pushed in 5.3:
always add it in this module, for `plan` too. Without it, Terraform uses
the default `rabbit-queue:latest`, which doesn't exist in ECR.

#### 5.5 Cluster, services, load balancer, security, auto-scaling

```bash
cd terraform/houda/platform
terraform init && terraform apply -var-file=terraform.tfvars
terraform output app_url    # the address of the API
cd ../../..
```

Creates the ECS cluster and its 4 services, the load balancer and its HTTPS
certificate, the Cognito user pool and test user, the IAM roles, the Cloud
Map names and the auto-scaling policies.

#### 5.6 Monitoring

```bash
cd terraform/aymen/05-monitoring
terraform init && terraform apply -var-file=terraform.tfvars
cd ../../..
```

Creates the dashboard, the 13 alarms and the SNS topic with your email.
AWS then emails you a link: click **Confirm subscription**, or the alarm
emails never arrive.

### Step 6. Check that everything runs

The services need 2 to 3 minutes after 5.5 to start and pass their health
checks.

```bash
aws ecs describe-services --cluster cloud-design-cluster \
  --services api-gateway-service inventory-service billing-service rabbit-queue-service \
  --query 'services[].{name:serviceName,desired:desiredCount,running:runningCount}' --output table

curl -k "$(terraform -chdir=terraform/houda/platform output -raw app_url)/health"
```

Expected: `running` equals `desired` (1) for every service, and `/health`
answers `{"service":"api-gateway-app","status":"ok"}`. Part 2.3 has more
checks.

### Step 7. Use the API

```bash
APP_URL=$(terraform -chdir=terraform/houda/platform output -raw app_url)
TOKEN=$(scripts/get-token.sh)            # Cognito access token, valid 60 minutes
AUTH="Authorization: Bearer $TOKEN"

curl -k -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"title": "Inception", "description": "Dreams within dreams"}' "$APP_URL/api/movies"
curl -k -H "$AUTH" "$APP_URL/api/movies"
curl -k -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"user_id": "1", "number_of_items": 2, "total_amount": 20}' "$APP_URL/api/billing"
```

`-k` accepts the load balancer's self-signed certificate (used when no
domain is set). On a machine without the Terraform state, get the address
from AWS instead:

```bash
APP_URL=https://$(aws elbv2 describe-load-balancers --names cloud-design-alb \
  --query 'LoadBalancers[0].DNSName' --output text)
```

### Step 8. Watch logs, metrics and alarms

```bash
# Follow a service's logs (stream prefixes: api-gateway, inventory, billing). Ctrl+C to stop.
aws logs tail /ecs/cloud-design --follow --log-stream-name-prefix inventory
aws logs tail /ecs/cloud-design-rabbit-queue --follow

# The alarms and their state
aws cloudwatch describe-alarms --alarm-name-prefix cloud-design- \
  --query 'MetricAlarms[].[AlarmName,StateValue]' --output table

# The dashboard's address
terraform -chdir=terraform/aymen/05-monitoring output -raw dashboard_url
```

### Step 9. Deploy a change

Changed application code reaches AWS inside the images:

```bash
scripts/push-images.sh
aws ecs update-service --cluster cloud-design-cluster --service inventory-service --force-new-deployment
aws ecs wait services-stable --cluster cloud-design-cluster --services inventory-service
```

Restart each service whose code changed: `api-gateway-service`,
`inventory-service`, `billing-service` or `rabbit-queue-service`. The app
services keep answering during the restart. RabbitMQ is stopped before its
replacement starts, so billing orders get `503` for about a minute.

Changed Terraform files are applied from their module's folder:

```bash
cd terraform/<aymen or houda>/<module>
terraform plan -var-file=terraform.tfvars     # read the plan first
terraform apply -var-file=terraform.tfvars
cd ../../..
```

### Step 10. Find a problem

```bash
CLUSTER=cloud-design-cluster

# Errors logged by the app services in the last hour
aws logs filter-log-events --log-group-name /ecs/cloud-design \
  --start-time $(( ($(date +%s) - 3600) * 1000 )) --filter-pattern '?ERROR ?Error ?Traceback' \
  --query 'events[].[logStreamName,message]' --output text

# Why tasks stopped in the last hour
aws ecs describe-tasks --cluster $CLUSTER \
  --tasks $(aws ecs list-tasks --cluster $CLUSTER --desired-status STOPPED --query 'taskArns[]' --output text) \
  --query 'tasks[].[group,stoppedReason,containers[0].exitCode]' --output table

# A shell inside a running container (needs the Session Manager plugin)
TASK=$(aws ecs list-tasks --cluster $CLUSTER --service-name inventory-service --query 'taskArns[0]' --output text)
aws ecs execute-command --cluster $CLUSTER --task $TASK --container inventory-app --interactive --command /bin/sh
```

How to install the Session Manager plugin without root is in
[terraform/houda/platform/README.md](terraform/houda/platform/README.md#cluster-access-task-6).

### Step 11. Run the project locally

```bash
cp .env.example .env              # first time only
docker compose up -d --build      # build and start the 5 containers
docker ps                         # every container should be "(healthy)"
curl localhost:8081/health        # inventory-app
curl localhost:8082/health        # billing-app
docker compose logs -f            # follow the logs (Ctrl+C to stop)
docker compose down --volumes     # stop and remove everything

scripts/smoke-test.sh             # build, start, check both /health, remove
scripts/test-billing-consumer.sh  # end to end: a queued order ends up in billing-db
```

The local stack runs everything but the gateway, which needs Cognito. With
Podman instead of Docker, run `export BUILDAH_FORMAT=docker` first: Podman's
default image format drops the Dockerfiles' `HEALTHCHECK`, and Compose then
waits forever for the databases to become healthy.

### Step 12. Load test

```bash
# terminal 1: task counts and CPU every 30 s (Ctrl+C to stop)
load-test/watch-scaling.sh

# terminal 2: about 17 minutes of traffic, peaking at 60 requests per second
load-test/run-load-test.sh
```

The results are in [load-test/README.md](load-test/README.md).

### Step 13. Check the costs and delete everything

The NAT gateway, the load balancer, the databases and the running tasks are
billed per hour. Check the spending in **Billing and Cost Management → Cost
Explorer**, and delete everything after testing, in reverse order:

```bash
cd terraform/aymen/05-monitoring  && terraform destroy -var-file=terraform.tfvars
cd ../../houda/platform           && terraform destroy -var-file=terraform.tfvars
cd ../../aymen/04-messaging       && terraform destroy -var-file=terraform.tfvars
cd ../../houda/ecr                && terraform destroy -var-file=terraform.tfvars
cd ../../aymen/02-databases       && terraform destroy -var-file=terraform.tfvars
cd ../01-networking               && terraform destroy -var-file=terraform.tfvars
```

## 2. Audit commands

The audit questions in order, with the commands to show and the result to
expect. `terraform plan` (2.8) must run on the machine that has the
Terraform state files; everything else works on any machine with the AWS
CLI configured.

### 2.1 Before you start

```bash
cd cloud-design                          # the repository root
export AWS_REGION=eu-west-3
aws sts get-caller-identity              # which AWS account and user the CLI uses

CLUSTER=cloud-design-cluster
APP_URL=https://$(aws elbv2 describe-load-balancers --names cloud-design-alb \
  --query 'LoadBalancers[0].DNSName' --output text)
TOKEN=$(scripts/get-token.sh)            # valid 60 minutes: run it again when it expires
AUTH="Authorization: Bearer $TOKEN"
```

### 2.2 Repository content

```bash
ls
ls srcs Dockerfiles scripts terraform/aymen terraform/houda
```

Expected: this README, the source code of the 4 services, the Dockerfiles,
the deployment scripts, the 6 Terraform modules and `docker-compose.yml`.
Part 3 below explains every file.

### 2.3 The deployment

```bash
# Every service: desired = running, "has reached a steady state"
aws ecs describe-services --cluster $CLUSTER \
  --services api-gateway-service inventory-service billing-service rabbit-queue-service \
  --query 'services[].{name:serviceName,desired:desiredCount,running:runningCount,event:events[0].message}' \
  --output table

# Every task: RUNNING and HEALTHY, spread over 2 availability zones
aws ecs describe-tasks --cluster $CLUSTER \
  --tasks $(aws ecs list-tasks --cluster $CLUSTER --query 'taskArns[]' --output text) \
  --query 'tasks[].{task:group,status:lastStatus,health:healthStatus,zone:availabilityZone}' --output table

# Service discovery: the private IP behind each internal name
for s in inventory-app billing-app rabbit-queue; do
  echo "$s.local: $(aws servicediscovery discover-instances --namespace-name local --service-name $s \
    --query 'Instances[].Attributes.AWS_INSTANCE_IPV4' --output text)"
done

# No errors in the logs during the last hour (empty output)
aws logs filter-log-events --log-group-name /ecs/cloud-design \
  --start-time $(( ($(date +%s) - 3600) * 1000 )) --filter-pattern '?ERROR ?Error ?Traceback' \
  --query 'events[].[logStreamName,message]' --output text
```

`docker ps` applies to the local stack ([step 11](#step-11-run-the-project-locally)):
`docker compose up -d --build`, then `docker ps` shows the 5 containers
`(healthy)`.

### 2.4 Load balancing

```bash
# Internet-facing, in 2 availability zones
aws elbv2 describe-load-balancers --names cloud-design-alb \
  --query 'LoadBalancers[0].{scheme:Scheme,state:State.Code,zones:AvailabilityZones[].ZoneName}'

# HTTPS on 443 (TLS 1.2/1.3 policy), HTTP on 80 redirects to HTTPS
LB=$(aws elbv2 describe-load-balancers --names cloud-design-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 describe-listeners --load-balancer-arn $LB \
  --query 'Listeners[].{port:Port,protocol:Protocol,tls:SslPolicy,action:DefaultActions[0].Type}' --output table

# Gateway tasks behind it: all "healthy"
TG=$(aws elbv2 describe-target-groups --names cloud-design-api-gateway-tg \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn $TG \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table
```

How traffic is spread: the load balancer sends requests to the healthy
gateway tasks in both zones; the gateway reaches inventory-app through Cloud
Map DNS, which returns the IPs of all healthy inventory tasks; RabbitMQ gives
each billing message to one of the billing tasks. When idle, each service
runs 1 task. To show the load balancer with 2 targets, one per zone:

```bash
TARGET=service/$CLUSTER/api-gateway-service

# Pause scale-in, so auto-scaling doesn't remove the extra task during the demo
aws application-autoscaling register-scalable-target --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id $TARGET \
  --suspended-state DynamicScalingInSuspended=true
aws ecs update-service --cluster $CLUSTER --service api-gateway-service --desired-count 2 >/dev/null
aws ecs wait services-stable --cluster $CLUSTER --services api-gateway-service

# Run again until both targets are "healthy" (about 30 s)
aws elbv2 describe-target-health --target-group-arn $TG \
  --query 'TargetHealthDescriptions[].[Target.Id,Target.AvailabilityZone,TargetHealth.State]' --output table

# Back to normal
aws ecs update-service --cluster $CLUSTER --service api-gateway-service --desired-count 1 >/dev/null
aws application-autoscaling register-scalable-target --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id $TARGET \
  --suspended-state DynamicScalingInSuspended=false
```

The load test (2.11) shows the gateway going from 1 to 4 tasks under load.

### 2.5 Communication between services

```bash
# Security groups: name, ID, open ports, which groups (or addresses) may connect
aws ec2 describe-security-groups --filters Name=group-name,Values='cloud-design-*' \
  --query 'SecurityGroups[].[GroupName,GroupId,join(`,`,IpPermissions[].to_string(FromPort)),join(`,`,IpPermissions[].UserIdGroupPairs[].GroupId),join(`,`,IpPermissions[].IpRanges[].CidrIp)]' \
  --output table

# Databases accept only SSL connections (value 1)
aws rds describe-db-parameters --db-parameter-group-name default.postgres16 \
  --query "Parameters[?ParameterName=='rds.force_ssl'].[ParameterName,ParameterValue]" --output text

# RabbitMQ's EFS volume: encrypted in transit, mounted with IAM authorization
aws ecs describe-task-definition --task-definition cloud-design-rabbit-queue \
  --query 'taskDefinition.volumes[0].efsVolumeConfiguration.{transitEncryption:transitEncryption,iam:authorizationConfig.iam}'
```

Expected: only the load balancer is open to the internet (80, 443); the app
tasks accept 3000 only from the load balancer and 8080 only from each other;
the databases accept 5432 and RabbitMQ 5672 only from the app tasks; EFS
accepts NFS only from RabbitMQ. Database and EFS traffic is encrypted, and
RabbitMQ requires a username and password. The gateway-to-inventory HTTP and
the AMQP traffic stay inside the private subnets unencrypted;
[README.md, Security](README.md#security) explains why.

### 2.6 The API: create and get movies

```bash
# Create a movie: 201 Created
curl -k -i -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"title": "Inception", "description": "Dreams within dreams"}' "$APP_URL/api/movies"

# Get all movies: 200, the list contains the new movie
curl -k -i -H "$AUTH" "$APP_URL/api/movies"

# Get one movie (put the id returned by the POST)
curl -k -i -H "$AUTH" "$APP_URL/api/movies/<id>"

# Search by title
curl -k -H "$AUTH" "$APP_URL/api/movies?title=incep"
```

The same requests are in the Postman collection (2.14).

### 2.7 Billing queue resilience

Orders sent while billing-app is stopped wait in RabbitMQ and are processed
when it comes back:

```bash
TARGET=service/$CLUSTER/billing-service

# 1. Stop billing-app. Auto-scaling is paused first so it doesn't start a task again.
aws application-autoscaling register-scalable-target --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id $TARGET \
  --suspended-state DynamicScalingInSuspended=true,DynamicScalingOutSuspended=true,ScheduledScalingSuspended=true
aws ecs update-service --cluster $CLUSTER --service billing-service --desired-count 0 >/dev/null
aws ecs wait services-stable --cluster $CLUSTER --services billing-service
# ...and until its task has really exited (it counts as not running as soon as it starts stopping)
aws ecs wait tasks-stopped --cluster $CLUSTER --tasks $(aws ecs list-tasks --cluster $CLUSTER \
  --service-name billing-service --desired-status STOPPED --query 'taskArns[]' --output text)
aws ecs describe-services --cluster $CLUSTER --services billing-service \
  --query 'services[0].runningCount'                                          # 0

# 2. Send an order: still accepted (200 Message posted), it waits in the queue
curl -k -i -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"user_id": "42", "number_of_items": 1, "total_amount": 9.99}' "$APP_URL/api/billing"

# 3. Start billing-app again and resume auto-scaling
aws ecs update-service --cluster $CLUSTER --service billing-service --desired-count 1 >/dev/null
aws application-autoscaling register-scalable-target --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount --resource-id $TARGET \
  --suspended-state DynamicScalingInSuspended=false,DynamicScalingOutSuspended=false,ScheduledScalingSuspended=false

# 4. The queued order is processed as soon as the new billing task connects
#    (about 30 s): "Received order message: {'user_id': '42', ...}", then
#    "Order successfully inserted". Ctrl+C to stop.
aws logs tail /ecs/cloud-design --log-stream-name-prefix billing --since 10m --follow
```

The log stream name in step 4 contains the ID of the new billing task,
which shows that the order was processed after the restart.

### 2.8 Terraform

On the machine that has the state files, from the repository root:

```bash
cd terraform/aymen/01-networking && terraform plan -var-file=terraform.tfvars
cd ../02-databases && terraform plan -var-file=terraform.tfvars
cd ../04-messaging && terraform plan -var-file=terraform.tfvars \
  -var "container_image=$(terraform -chdir=../../houda/ecr output -raw rabbit_queue_image)"
cd ../../houda/ecr && terraform plan -var-file=terraform.tfvars
cd ../platform && terraform plan -var-file=terraform.tfvars
cd ../../aymen/05-monitoring && terraform plan -var-file=terraform.tfvars
cd ../../..

# What one module manages and exports
terraform -chdir=terraform/houda/platform state list
terraform -chdir=terraform/houda/platform output
```

Expected in every module: `No changes. Your infrastructure matches the
configuration.` Running `terraform apply` with the same arguments is safe:
with nothing to change it ends with `0 added, 0 changed, 0 destroyed`.

### 2.9 Containers and orchestration

```bash
# The Dockerfiles: two stages, slim base, non-root user, health check
cat Dockerfiles/inventory-app/Dockerfile

# Image sizes as stored in ECR (compressed, bytes) and when they were pushed
for r in api-gateway-app inventory-app billing-app rabbit-queue; do
  aws ecr describe-images --repository-name cloud-design/$r --image-ids imageTag=latest \
    --query 'imageDetails[0].[repositoryName,imageSizeInBytes,imagePushedAt]' --output text
done

# A task definition: size, image, port, secrets, health check, logs
aws ecs describe-task-definition --task-definition cloud-design-inventory \
  --query 'taskDefinition.{cpu:cpu,memory:memory,network:networkMode,image:containerDefinitions[0].image,port:containerDefinitions[0].portMappings[0].containerPort,secrets:containerDefinitions[0].secrets[].name,healthCheck:containerDefinitions[0].healthCheck.command[1],logGroup:containerDefinitions[0].logConfiguration.options."awslogs-group"}'

# A service: Fargate, private subnets without public IP, rollback on failure
aws ecs describe-services --cluster $CLUSTER --services inventory-service \
  --query 'services[0].{launchType:launchType,taskDefinition:taskDefinition,circuitBreaker:deploymentConfiguration.deploymentCircuitBreaker,publicIp:networkConfiguration.awsvpcConfiguration.assignPublicIp,subnets:networkConfiguration.awsvpcConfiguration.subnets}'
```

Locally, `docker images` shows the image sizes after `docker compose build`.
[README.md, section 6](README.md#6-docker-images) has the build times and
sizes before and after optimization.

### 2.10 Monitoring and logging

Dashboard: CloudWatch → **Dashboards** → `cloud-design-overview`, or
<https://eu-west-3.console.aws.amazon.com/cloudwatch/home?region=eu-west-3#dashboards:name=cloud-design-overview>.

| Graph | Shows |
|-------|-------|
| Requests per minute, Response time, HTTP errors per minute | Traffic, latency (p95) and 4xx/5xx errors at the load balancer |
| api-gateway targets | Healthy and unhealthy gateway tasks |
| Running tasks per service, Service CPU, Service memory | Each ECS service's task count and resource use |
| Billing orders saved per minute, App errors (latest 50) | Queries on the app logs |
| RDS CPU, RDS free storage, RDS connections | Both databases |
| rabbit-queue error count, rabbit-queue recent logs | The broker's health |

```bash
# 13 alarms and their state (OK = no problem). They email alert_email through SNS.
aws cloudwatch describe-alarms --alarm-name-prefix cloud-design- \
  --query 'MetricAlarms[].[AlarmName,StateValue]' --output table

# The email subscription (an ARN instead of "PendingConfirmation" = confirmed)
aws sns list-subscriptions \
  --query 'Subscriptions[?contains(TopicArn,`cloud-design`)].[Protocol,Endpoint,SubscriptionArn]' --output table

# Logs of each service
aws logs tail /ecs/cloud-design --since 10m --log-stream-name-prefix api-gateway
aws logs tail /ecs/cloud-design-rabbit-queue --since 1h
```

The alarms: API down (no healthy gateway task), more than 10 server errors
in 5 minutes, a service with no running task, database CPU above 80 %, free
storage below 2 GB, more than 50 connections, and any error in RabbitMQ's
logs. Graphs taken during the load test are in
[terraform/aymen/05-monitoring/README.md](terraform/aymen/05-monitoring/README.md#screenshots).

### 2.11 Auto-scaling and load

```bash
# Each app service: 1 to 4 tasks
aws application-autoscaling describe-scalable-targets --service-namespace ecs \
  --query 'ScalableTargets[].[ResourceId,MinCapacity,MaxCapacity]' --output table

# Policies: CPU 60 % on each service, 600 requests per minute per gateway task
aws application-autoscaling describe-scaling-policies --service-namespace ecs \
  --query 'ScalingPolicies[].[PolicyName,TargetTrackingScalingPolicyConfiguration.TargetValue]' --output table

# What auto-scaling did (the load test made the gateway go from 1 to 4 tasks and back)
aws application-autoscaling describe-scaling-activities --service-namespace ecs --max-items 10 \
  --query 'ScalingActivities[].[StartTime,ResourceId,Description]' --output table
```

Load test results at 60 requests per second (details in
[load-test/README.md](load-test/README.md)): about 48,000 requests, 0 %
errors, p95 latency 89 ms. The gateway scaled from 1 to 4 tasks within
7.5 minutes and back to 1 about 25 minutes after the load stopped. Inventory
(36 % CPU at most) and billing (7 %) stayed at 1 task, as expected.

### 2.12 Security

```bash
# HTTP is redirected to HTTPS
curl -sI "${APP_URL/https:/http:}/health" | head -1                 # 301 Moved Permanently

# Requests without a valid token are rejected
curl -k -i "$APP_URL/api/movies"                                    # 401 Missing bearer token
curl -k -i -H "Authorization: Bearer fake" "$APP_URL/api/movies"    # 401 Invalid or expired token

# Databases: not public, encrypted
aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier,PubliclyAccessible,StorageEncrypted,EngineVersion]' --output table

# Credentials are in Secrets Manager; each service can read only its own
aws secretsmanager list-secrets --query 'SecretList[?starts_with(Name,`cloud-design/`)].Name' --output table
aws iam get-role-policy --role-name cloud-design-inventory-execution \
  --policy-name cloud-design-inventory-read-secrets --query 'PolicyDocument.Statement[0].Resource'

# Vulnerability scanning: continuous Inspector scans, findings of the deployed images
aws ecr get-registry-scanning-configuration \
  --query 'scanningConfiguration.[scanType,rules[0].scanFrequency]' --output text
aws inspector2 list-findings --sort-criteria field=SEVERITY,sortOrder=DESC \
  --filter-criteria '{"ecrImageRepositoryName":[{"comparison":"PREFIX","value":"cloud-design/"}],"ecrImageTags":[{"comparison":"EQUALS","value":"latest"}],"findingStatus":[{"comparison":"EQUALS","value":"ACTIVE"}]}' \
  --query 'findings[].[resources[0].details.awsEcrContainerImage.repositoryName,severity,title]' --output table

# Cognito: user pool, password policy, app client, users
POOL=$(aws cognito-idp list-user-pools --max-results 10 \
  --query "UserPools[?Name=='cloud-design-users'].Id" --output text)
aws cognito-idp describe-user-pool --user-pool-id $POOL \
  --query 'UserPool.{name:Name,passwordPolicy:Policies.PasswordPolicy}'
CLIENT=$(aws cognito-idp list-user-pool-clients --user-pool-id $POOL \
  --query 'UserPoolClients[0].ClientId' --output text)
aws cognito-idp describe-user-pool-client --user-pool-id $POOL --client-id $CLIENT \
  --query 'UserPoolClient.{name:ClientName,authFlows:ExplicitAuthFlows,accessTokenMinutes:AccessTokenValidity}'
aws cognito-idp list-users --user-pool-id $POOL --query 'Users[].[Username,UserStatus]' --output table
```

About the scan results: when a finding has a fixed version, update the
package (in the service's `requirements.txt` or its Dockerfile) and push the
image again; Inspector scans the new image automatically. The remaining
critical finding is in rabbit-queue: Debian 12 ships RabbitMQ 3.10.8 and has
no fixed version yet. Moving to a newer RabbitMQ means a major upgrade, which
can't open the queue data already stored on EFS, so it is planned as a
separate migration. Until then the risk is limited: RabbitMQ is reachable
only from the app tasks in the private subnets and needs a password.

### 2.13 Bonus

Beyond the required parts:

- Continuous vulnerability scanning with Amazon Inspector
- A CloudWatch dashboard and 13 alarms with email alerts
- A k6 load test with measured results, scaling timeline and tuning decisions
- Deployment circuit breaker: a failing new version is rolled back automatically
- ECS Exec: a shell inside a running container for debugging
- RabbitMQ publisher confirms and data on EFS: an accepted order is never lost
- A local Docker Compose stack with an end-to-end billing test
- An OpenAPI description of the API and a Postman collection with automatic checks

### 2.14 Testing with Postman

[postman/cloud-design.postman_collection.json](postman/cloud-design.postman_collection.json)
has 14 requests with automatic checks, in 4 folders:

| Folder | Requests |
|--------|----------|
| 1. Sign in | Gets a Cognito access token and saves it for all the other requests |
| 2. Security checks | `/health` without a token (200), movies without a token (401), with a fake token (401) |
| 3. Movies | Create (201), list, get by id, search, update (200), create without a title (400), delete, get the deleted movie (404) |
| 4. Billing | Send an order (200 Message posted), an order with missing fields (400) |

1. Get the values the collection needs:

   ```bash
   # base_url
   echo "https://$(aws elbv2 describe-load-balancers --names cloud-design-alb \
     --query 'LoadBalancers[0].DNSName' --output text)"

   # cognito_client_id, username and password of the test user
   aws secretsmanager get-secret-value --secret-id cloud-design/cognito-test-user \
     --query SecretString --output text
   ```

2. In Postman: **Import** → choose the file. Open the collection, go to the
   **Variables** tab and fill `base_url`, `cognito_client_id`, `username` and
   `password`. Type the password only as the *current* (local) value, not
   as the initial or shared value: the local value stays on your computer
   and is never exported with the collection. Save.
3. Run **1. Sign in → Get access token**. The token is saved in
   `access_token` and is valid 60 minutes; run it again when requests
   start getting 401.
4. Run the other requests one by one, or the whole collection with
   **Run collection**. Each request's **Test Results** tab shows its checks.

The requests to the load balancer don't verify its certificate, because it
is self-signed when no domain is set. If Postman still reports a certificate
error, turn off **Settings → General → SSL certificate verification**.

For the billing resilience test (2.7), stop billing-app with the step 1
commands, send **4. Billing → Send a billing order** from Postman, then run
steps 3 and 4.

The collection deletes only the movie it creates. `DELETE /api/movies`,
which deletes every movie, is left out on purpose.

## 3. What every file does

### Root folder

| File | What it does |
|------|--------------|
| `README.md` | The project documentation: architecture, design decisions, configuration, commands, Docker images |
| `COMMANDS.md` | This file: using AWS step by step, the audit commands, what every file does |
| `Tasks.md` | How the work was split into 10 tasks between the two team members |
| `docker-compose.yml` | Runs the backend locally: inventory-db, billing-db, rabbit-queue, inventory-app, billing-app. The gateway isn't included: it needs a Cognito user pool, so it is tested on AWS |
| `.env.example` | Example settings for Docker Compose (database and RabbitMQ users, passwords, names). Copy it to `.env`, which git ignores |
| `.gitignore` | Keeps secrets and generated files out of git: `.env`, `*.tfvars`, Terraform state and `.terraform/` folders, plan files, load-test results |
| `.dockerignore` | Keeps everything except the source code out of the Docker build context: faster builds, and no state files or `.env` in images |
| `openapi.yaml` | OpenAPI 3 description of the public API: paths, request bodies, responses, the Bearer token security |
| `postman/cloud-design.postman_collection.json` | Postman collection: 14 requests with automatic checks (2.14) |

### `srcs/`: application source code

**api-gateway-app** (Python, Flask, gunicorn)

| File | What it does |
|------|--------------|
| `server.py` | Entry point: gunicorn runs `server:app` on port 3000 |
| `app/__init__.py` | `create_app()`: builds the Flask app and registers the routes |
| `app/auth.py` | Checks the Cognito access token on every `/api/*` request (signature with the user pool's public keys, expiry, issuer, token type, client id) and answers 401 otherwise. Stops the app at start if the Cognito settings are missing |
| `app/routes.py` | `/health`; forwards `/api/movies` requests to inventory-app; checks `/api/billing` orders and publishes them to RabbitMQ, waiting for RabbitMQ's confirmation |
| `requirements.txt` | Pinned Python packages: Flask, gunicorn, requests, pika (RabbitMQ), PyJWT (tokens), python-dotenv |

**inventory-app** (Python, Flask, SQLAlchemy, gunicorn)

| File | What it does |
|------|--------------|
| `server.py` | Entry point: gunicorn runs `server:app` on port 8080 |
| `app/__init__.py` | `create_app()`: reads the `INVENTORY_DB_*` settings, connects to PostgreSQL and creates the `movies` table if needed |
| `app/models.py` | The `movies` table: id, title, description |
| `app/routes.py` | `/health` (also checks the database) and the movie API: list, search by title, create and delete all on `/api/movies`; get, update and delete one on `/api/movies/{id}` |
| `requirements.txt` | Flask, Flask-SQLAlchemy, gunicorn, psycopg2 (PostgreSQL driver), python-dotenv |

**billing-app** (Python, pika, SQLAlchemy)

| File | What it does |
|------|--------------|
| `server.py` | Entry point: starts the consumer |
| `app/__init__.py` | Empty; marks `app/` as a Python package |
| `app/consumer.py` | Health endpoint on 8080; waits for billing-db; reads `billing_queue` one message at a time; saves each order and acks it only after the insert; puts it back in the queue while the database is down; reconnects when RabbitMQ restarts; stops cleanly when ECS stops the task |
| `app/database.py` | Database connection (SQLAlchemy engine and sessions) built from the `BILLING_DB_*` settings |
| `app/models.py` | The `orders` table: id, user_id, number_of_items, total_amount |
| `requirements.txt` | pika, Flask (health endpoint), SQLAlchemy, psycopg2, python-dotenv |

**Start scripts**

| File | What it does |
|------|--------------|
| `srcs/rabbit-queue/docker-entrypoint.sh` | RabbitMQ's start script. On the first start it creates the app user from `RABBITMQ_USER`/`RABBITMQ_PASSWORD`, gives it permissions and deletes the default `guest` user. Then it runs RabbitMQ as the `rabbitmq` user |
| `srcs/database/docker-entrypoint.sh` | Start script of the local PostgreSQL images. On the first start it creates the data folder, the user, the password and the database. Then it runs PostgreSQL as the `postgres` user |

### `Dockerfiles/`

| File | What it does |
|------|--------------|
| `api-gateway-app/Dockerfile` | Two stages on `python:3.12-slim-trixie`: the first installs the packages in a virtual environment, the second copies only that environment and the code. Runs gunicorn on 3000 as a non-root user, with a `/health` health check |
| `inventory-app/Dockerfile` | Same pattern, port 8080 |
| `billing-app/Dockerfile` | Same pattern, runs `python server.py` |
| `rabbit-queue/Dockerfile` | `debian:12-slim` with Debian's `rabbitmq-server` and the latest security updates; node name `rabbit@localhost`; health check with `rabbitmq-diagnostics` |
| `inventory-db/Dockerfile`, `billing-db/Dockerfile` | `debian:12-slim` with PostgreSQL 15, for the local Docker Compose stack only. On AWS the databases are RDS |

### `scripts/`

| File | What it does |
|------|--------------|
| `push-images.sh` | Builds the 4 images for linux/amd64 and pushes them to ECR. Works with Docker or Podman |
| `get-token.sh` | Prints a Cognito access token (valid 60 minutes) for the test user. Reads the password from Secrets Manager without showing it |
| `smoke-test.sh` | Local: builds and starts Docker Compose, checks the `/health` of inventory-app and billing-app, then removes everything |
| `test-billing-consumer.sh` | Local: puts a test order on the queue and checks that billing-app saved it in billing-db |

### `load-test/`

| File | What it does |
|------|--------------|
| `README.md` | How the load test works and how to run it, with the measured results: latency, errors, scaling timeline, CPU, tuning decisions |
| `k6-script.js` | The k6 test: creates 20 movies, then sends a mix of movie reads and billing orders, ramping up to `PEAK_RPS` requests per second |
| `run-load-test.sh` | Runs k6 in a container against the deployed app with a fresh token, and saves the output in `load-test/results/` |
| `watch-scaling.sh` | Every 30 s, prints the task count and CPU of each app service, to watch auto-scaling during the test |

### `terraform/`

Six modules, each applied on its own from its own folder. `aymen/` holds
tasks 1, 2, 4 and 5, `houda/` tasks 6 to 9. A module that needs another
one's IDs reads them from that module's state file (`terraform_remote_state`).

**Files found in every module**

| File | What it does |
|------|--------------|
| `versions.tf` | Required Terraform and provider versions, and the AWS region |
| `variables.tf` | The module's settings, with defaults |
| `terraform.tfvars.example` | Example values: copy it to `terraform.tfvars` (git-ignored) and change what you need |
| `outputs.tf` | Values the module exports for other modules and scripts (IDs, names, URLs) |
| `.terraform.lock.hcl` | The exact provider versions, so every machine uses the same ones |
| `README.md` | Details of the module |

**`aymen/01-networking`**: the network (task 1)

| File | What it does |
|------|--------------|
| `vpc.tf` | The VPC (10.0.0.0/16) with DNS support |
| `subnets.tf` | 2 public and 2 private subnets, one of each per availability zone |
| `internet_gateway.tf` | The internet gateway and the public route table |
| `nat_gateway.tf` | One NAT gateway with its Elastic IP, and the private route table: outbound-only internet for the private subnets |
| `security_groups.tf` | `alb` (80 and 443 from the internet), `app` (3000 from alb), `db` (5432 from app), `rabbitmq` (5672 from app) |

**`aymen/02-databases`**: the databases (task 2)

| File | What it does |
|------|--------------|
| `inventory_db.tf`, `billing_db.tf` | The two RDS PostgreSQL instances: private, encrypted, 7 days of backups |
| `subnet_group.tf` | Places the databases in the private subnets |
| `secrets.tf` | Generates the passwords and stores username, password and database name in Secrets Manager |
| `data.tf` | Reads the subnet and security group IDs from 01-networking |

**`aymen/04-messaging`**: RabbitMQ (task 4)

| File | What it does |
|------|--------------|
| `task_definition.tf` | RabbitMQ's ECS task definition (image, secrets, EFS volume, health check) and its log group |
| `efs.tf` | Encrypted EFS file system, a mount target in each private subnet, an access point, and the `efs` security group (NFS only from RabbitMQ) |
| `iam.tf` | Execution role (pull the image, write logs, read the RabbitMQ secret) and task role (mount EFS through the access point) |
| `secrets.tf` | RabbitMQ username, generated password and queue name in Secrets Manager |
| `data.tf` | Reads the VPC, subnet and security group IDs from 01-networking |
| `TOPOLOGY.md` | Diagram and details of the queue: exchange, routing, durability, acknowledgements |

**`aymen/05-monitoring`**: monitoring and alerts (task 5)

| File | What it does |
|------|--------------|
| `dashboard.tf` | The CloudWatch dashboard `cloud-design-overview` (14 graphs, listed in 2.10) |
| `app_alarms.tf` | Alarms: no healthy gateway task, too many server errors (5xx), a service with no running task |
| `rds_alarms.tf` | Alarms per database: high CPU, low free storage, too many connections |
| `log_alarms.tf` | Counts errors in RabbitMQ's logs and raises an alarm on any |
| `sns.tf` | The SNS topic the alarms publish to, and the email subscription |
| `data.tf` | Reads the databases, messaging and platform outputs |
| `screenshots/*.png` | CloudWatch graphs during the load test: requests and tasks, CPU, response time |

**`houda/ecr`**: image registry and scanning (tasks 6 and 8)

| File | What it does |
|------|--------------|
| `main.tf` | The 4 ECR repositories (encrypted, keep the last 5 images), Amazon Inspector turned on, and continuous enhanced scanning |

**`houda/platform`**: cluster, load balancer, security, auto-scaling (tasks 6 to 9)

| File | What it does |
|------|--------------|
| `cluster.tf` | The ECS cluster and the log group of the app containers |
| `tasks.tf` | Task definitions of api-gateway-app, inventory-app and billing-app: image, CPU and memory, settings, secrets, health check, logs |
| `services.tf` | The 4 ECS services: private subnets, no public IP, load balancer (gateway), Cloud Map names, circuit breaker |
| `alb.tf` | The load balancer, the gateway's target group with its `/health` check, the HTTPS listener and the HTTP-to-HTTPS redirect |
| `certificate.tf` | The HTTPS certificate: a public ACM certificate if a domain is set, otherwise a self-signed one imported into ACM |
| `cognito.tf` | User pool, app client, test user, and the test user's secret |
| `iam.tf` | Per-service execution roles (read only their own secrets) and task roles (ECS Exec only) |
| `security_groups.tf` | The `services-internal` group: the app tasks can reach each other on 8080 |
| `service_discovery.tf` | Cloud Map namespace `local` with the names inventory-app, billing-app and rabbit-queue |
| `autoscaling.tf` | Scaling targets (1-4 tasks) and target-tracking policies (CPU 60 %, 600 requests per minute per gateway task) |
| `data.tf` | Reads the networking, databases, messaging and ECR outputs, and builds the image URIs |
