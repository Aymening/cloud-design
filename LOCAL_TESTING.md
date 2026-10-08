# Local testing (Task 3: containerize inventory-app & billing-app)

`docker-compose.yml` at the repo root runs the backend services locally:
`inventory-db`, `billing-db`, `rabbit-queue`, `inventory-app`, `billing-app`.
`api-gateway-app` is not part of it: it needs a Cognito user pool to check
tokens and refuses to start without one, so it is tested on AWS.

## Running it

```bash
cp .env.example .env   # first time only
./scripts/smoke-test.sh
```

With Podman instead of Docker, run `export BUILDAH_FORMAT=docker` first:
Podman's default image format drops the Dockerfiles' `HEALTHCHECK`, and
Compose then waits forever for the databases to become healthy.

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
build to a multi-stage build on `python:3.12-slim` (now pinned to
`python:3.12-slim-trixie`). The builder stage installs into a venv, the
final stage copies only the venv + app code, so pip/apt metadata never end
up in the shipped image. Measured on this machine:

| Image | Before | After | Change |
|---|---|---|---|
| `inventory-app` | 342 MB | 281 MB | ~18% smaller |
| `billing-app` | 336 MB | 276 MB | ~18% smaller |

Build time also dropped (less to install/unpack in the final stage), though
that's noisier to measure since it depends on what's already cached locally.

### All deployed images

Measured on 2026-10-06 with Podman, building with `--no-cache` (nothing
reused). "Compressed" is the size stored in ECR, which is what Fargate
downloads when a task starts.

| Image | Base | Build time | Size | Compressed (ECR) |
|---|---|---|---|---|
| `api-gateway-app` | `python:3.12-slim-trixie`, multi-stage | 18 s | 165 MB | 54 MB |
| `inventory-app` | `python:3.12-slim-trixie`, multi-stage | 18 s | 179 MB | 58 MB |
| `billing-app` | `python:3.12-slim-trixie`, multi-stage | 18 s | 174 MB | 57 MB |
| `rabbit-queue` | `debian:12-slim` + Debian's `rabbitmq-server` | 19 s | 194 MB | 80 MB |

Other choices that keep builds fast and images small and safe:

- `requirements.txt` is copied and installed before the source code, so a
  code change reuses the cached dependency layer and rebuilds in seconds.
- The Python base is pinned to a Debian release (`-trixie`), so it can't
  change underneath us without a Dockerfile change.
- `rabbit-queue` and the database images run `apt-get upgrade` so they get
  Debian's latest security fixes (this removed the critical `perl` findings
  Amazon Inspector reported on `rabbit-queue`).
- Every app runs as a non-root user. `rabbit-queue` and the databases start
  as root only to set up their data directory, then run the server as the
  `rabbitmq`/`postgres` user.
- `.dockerignore` keeps everything except `srcs/` out of the build context.
  Docker sends the whole context to the builder before building, and
  without it that would include about 1.4 GB of `.terraform` provider
  folders, Terraform state (which holds database passwords) and `.env`.

With Podman, build with `BUILDAH_FORMAT=docker` (or `--format docker`):
Podman's default OCI format drops the `HEALTHCHECK`, and then
`docker compose up` waits forever for the databases to become healthy.

## A real bug this surfaced

Running the stack from a clean state (`docker compose down --volumes`
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
