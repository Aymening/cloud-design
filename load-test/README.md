# Load test and auto-scaling check (Task 9)

Checks that the auto-scaling policies in `terraform/houda/platform/autoscaling.tf`
add tasks under load and remove them afterwards, and gives the numbers used
to tune their thresholds.

## What the test does

`k6-script.js` runs in a container (`grafana/k6`), so nothing has to be
installed. It goes through the public load balancer with a Cognito token,
like a real client:

1. **Setup:** creates 20 movies named `load-test-movie-N`. Reads then hit a
   small table whose size doesn't change during the test.
2. **Traffic mix:** 60 % `GET /api/movies?title=load-test-movie`, 20 %
   `GET /api/movies/{id}`, 20 % `POST /api/billing` (goes through RabbitMQ
   to billing-app and billing-db).
3. **Shape**, in requests per second (`PEAK_RPS`, default 60):

   | Phase | Duration | Load |
   |-------|----------|------|
   | Warm-up | 2 min | 1 → PEAK/3 |
   | Ramp | 3 min | → PEAK |
   | Hold | 10 min | PEAK (scale-out should happen here) |
   | Ramp down | 2 min | → 0 (scale-in follows about 15 min later) |

   The load is set as a number of requests started per second, not a
   number of users. So it doesn't drop when responses get slower, which is
   exactly when scaling has to react.
4. **Pass criteria:** less than 5 % failed requests and 95th percentile
   latency under 2 s.

The test leaves its movies and billing orders in the databases; it never
calls `DELETE /api/movies`, which would delete every movie.

## Running it

Two terminals, from the repository root:

```bash
# terminal 1: record task counts and CPU every 30 s (Ctrl+C to stop)
load-test/watch-scaling.sh

# terminal 2: run the test (about 17 minutes)
load-test/run-load-test.sh
# or with a different peak:
PEAK_RPS=120 load-test/run-load-test.sh
```

Keep `watch-scaling.sh` running for about 20 minutes after k6 finishes to
see the scale-in. Both scripts save their output in `load-test/results/`.

The ECS console (cluster → service → **Health and metrics**) and CloudWatch
(**Alarms**: the `TargetTracking-service/cloud-design-cluster/...` alarms
that auto-scaling created) show the same thing as graphs.

## Results

To be filled in after running the test on AWS.

**Before auto-scaling:** with `autoscaling_max_capacity = 1` (one task
per service), from the k6 summary:

| Peak req/s | Requests | Failed % | p95 latency | Notes |
|------------|----------|----------|-------------|-------|
| | | | | |

**With auto-scaling:** default settings (CPU 60 %, 600 req/min per
gateway task, max 4 tasks):

| Peak req/s | Requests | Failed % | p95 latency | Notes |
|------------|----------|----------|-------------|-------|
| | | | | |

**Scaling timeline** (from `watch-scaling.sh`):

| Time | Event | api-gateway | inventory | billing |
|------|-------|-------------|-----------|---------|
| | test start | 1 | 1 | 1 |
| | first scale-out | | | |
| | peak task count | | | |
| | load stops | | | |
| | back to 1 task | | | |

**Tuning decisions:**

- _e.g. "scale-out took N min; lowered gateway_requests_per_target from 600 to ..."_

## How to read the results

- **Scale-out works** if the task count goes up during the hold phase and
  the failed rate and p95 latency get better after the new tasks start,
  compared to the one-task run.
- **Scale-in works** if every service goes back to 1 task some time after
  the test ends.
- If a service reaches its maximum while CPU is still above target, raise
  `autoscaling_max_capacity` or `task_cpu`. If it scales up and down
  repeatedly, raise the target or the cooldowns.
