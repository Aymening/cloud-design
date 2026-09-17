# Cloud-Design

## Overview

This project designs, deploys, and operates a cloud-based microservices
application on AWS, using Terraform, Docker, and AWS orchestration (ECS/EKS).
It covers networking, storage, load balancing, auto-scaling, security, and
observability for the following services:

- `inventory-db` — PostgreSQL, port `5432`
- `billing-db` — PostgreSQL, port `5432`
- `inventory-app` — connects to `inventory-db`, port `8080`
- `billing-app` — connects to `billing-db`, consumes from `rabbit-queue`, port `8080`
- `rabbit-queue` — RabbitMQ
- `api-gateway-app` — routes requests to the other services, port `3000`

## Task Breakdown

The work is split into 10 independent tasks, 5 owned by **Aymen** and 5 owned
by **Houda**. Each task can be started and carried out without waiting on any
other task to finish — integration happens once all tasks land. Every task
owner is responsible for provisioning their piece with Terraform, documenting
their decisions, and keeping cost in check (destroy/stop idle resources).

### Aymen's tasks

| # | Task | Description | Deliverables |
|---|------|-------------|---------------|
| 1 | **Networking foundation (VPC)** | Design and provision the AWS VPC: public/private subnets across multiple AZs, route tables, internet gateway, NAT gateway, and security groups for each service tier. | Terraform module for VPC/networking; network diagram; security group rules documented. |
| 2 | **Databases (inventory-db & billing-db)** | Provision the two PostgreSQL databases (RDS or containerized on private subnets), accessible only from within the VPC on port `5432`, with encryption at rest and automated backups. | Terraform module for both databases; connection details (via secrets, not hardcoded); backup/retention policy documented. |
| 3 | **Containerize inventory-app & billing-app** | Write optimized Dockerfiles (multi-stage builds, minimal base images) for `inventory-app` and `billing-app`, connect each to its database, and validate locally with Docker Compose. | Dockerfiles; docker-compose.yml for local testing; image size/build time notes. |
| 4 | **Message queue (rabbit-queue) & billing consumer wiring** | Deploy RabbitMQ as a container, configure the queue(s)/exchange used by `billing-app`, and verify `billing-app` correctly consumes messages end-to-end. | Terraform/deployment config for `rabbit-queue`; queue topology diagram; test showing message consumption. |
| 5 | **Monitoring & logging** | Set up CloudWatch (or Prometheus/Grafana) dashboards and centralized logging (e.g. ELK or CloudWatch Logs) for all services, plus basic health-check alarms. | Dashboards/config as code where possible; alerting rules; screenshots in docs. |

### Houda's tasks

| # | Task | Description | Deliverables |
|---|------|-------------|---------------|
| 6 | **Container orchestration cluster (ECS/EKS)** | Stand up the orchestration platform (ECS cluster or EKS cluster, using the `orchestrator` project as a base) that will run all app containers, including task/service definitions or Kubernetes manifests. | Terraform for the cluster; base task/service (or Helm/K8s) definitions; cluster access documented. |
| 7 | **API Gateway app + Load Balancer** | Containerize and deploy `api-gateway-app` (port `3000`) behind an AWS Elastic Load Balancer, routing traffic to `inventory-app`, `billing-app`, and correctly handling service discovery. | Dockerfile for `api-gateway-app`; ALB/target group Terraform; routing rules documented. |
| 8 | **Security & access management** | Implement HTTPS via AWS Certificate Manager, managed authentication for public endpoints (Cognito or equivalent), IAM roles/policies scoped per service, and secrets management (e.g. Secrets Manager/SSM Parameter Store). | Terraform for ACM/Cognito/IAM/secrets; security decisions documented; no plaintext credentials in repo. |
| 9 | **Auto-scaling & load testing** | Define auto-scaling policies (target tracking or step scaling) for the app services, and run load tests to validate scale-out/scale-in behavior and tune thresholds. | Terraform auto-scaling config; load test scripts/results; before/after scaling behavior notes. |
| 10 | **Architecture documentation & diagrams** | Produce the overall architecture diagram(s) tying every component together, write the design-decision rationale (scalability, availability, security, cost, simplicity trade-offs), and assemble the final setup/usage guide. | Architecture diagrams; design rationale section; prerequisites/setup/usage instructions. |

`FIGHTING AND BE HAPPY`

## Notes

- Each task owner provisions their resources via Terraform in their own
  directory/module so tasks don't block each other; final integration wires
  the modules together once all pieces are ready.
- Databases and other private resources must remain accessible only from
  within the VPC — never expose them publicly.
- Remember to tear down or stop unused AWS resources after testing to avoid
  unnecessary costs.
