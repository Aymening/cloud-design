# Local testing (Task 3: containerize inventory-app & billing-app)

`docker-compose.yml` at the repo root runs the full stack locally:
`inventory-db`, `billing-db`, `rabbit-queue`, `inventory-app`, `billing-app`.

## Running it

```bash
cp .env.example .env   # first time only
./scripts/smoke-test.sh
```

The script builds everything, starts it, polls both apps' `/health`
endpoints for up to a minute, prints their responses, then tears the whole
stack down (`docker compose down --volumes`).

To just run it and leave it up for manual poking:

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f
docker compose down --volumes   # when done
```

`inventory-app` is on `localhost:8081`, `billing-app` on `localhost:8082`,
RabbitMQ AMQP on `localhost:5672`.

## Dockerfile optimization: before vs after

Both `inventory-app` and `billing-app` moved from a single-stage
`debian:12-slim` + manual `apt-get install python3 python3-pip python3-venv`
build to a multi-stage build on `python:3.12-slim` (builder stage installs
into a venv, final stage copies only the venv + app code, so pip/apt
metadata never end up in the shipped image). Measured on this machine:

| Image | Before | After | Change |
|---|---|---|---|
| `inventory-app` | 342 MB | 281 MB | ~18% smaller |
| `billing-app` | 336 MB | 276 MB | ~18% smaller |

Build time also dropped (less to install/unpack in the final stage), though
that's noisier to measure since it depends on what's already cached locally.

## A real bug this surfaced

Running the full stack from a clean state (`docker compose down --volumes`
then up) exposed a startup-order race: `inventory-db` and `rabbit-queue`
both run a first-boot init script that briefly starts their server process,
configures it (creates the role/db, or the user/queue), then restarts it
into its final state. Their `HEALTHCHECK` can report healthy a moment before
that final restart settles, so the very first connection attempt from
`inventory-app`/`billing-app` can land on the transient instance and get
dropped.

Fix: `restart: on-failure:5` on both app services in `docker-compose.yml`.
It's a one-time cold-start race, so a single automatic restart resolves it —
confirmed by tearing everything down and rerunning `smoke-test.sh` from
scratch. This mirrors how ECS/EKS will behave in production anyway (a task
that dies gets restarted by the scheduler), so it's not a workaround unique
to local testing.

## Known limitation

`inventory-db`/`billing-db` here are plain Postgres containers, used only
for this local Docker Compose stack. In AWS, the actual databases are the
RDS instances from `terraform/aymen/02-databases/` — this compose file is
for local dev/testing only, not a preview of the AWS deployment.
