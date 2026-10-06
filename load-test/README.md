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

Two runs on 2026-10-06 at `PEAK_RPS=60` with the default settings (CPU
60 %, 600 req/min per gateway task, 1 to 4 tasks per service). Each run
started with 1 task per service.

| Run | Peak req/s | Requests | Failed % | p95 latency | Notes |
|-----|------------|----------|----------|-------------|-------|
| 1 | 60 | 48,079 | 0 % | 89 ms | average 61 ms, slowest 1.1 s |
| 2 | 60 | 48,069 | 0 % | 96 ms | one request took 32 s because of a network drop on the test machine (the load balancer's slowest response that minute was 0.6 s); 11 of about 48,000 requests couldn't start on time |

Both runs pass the thresholds (failed < 5 %, p95 < 2 s). An earlier
attempt reported p95 = 3.08 s, but the laptop running k6 went to sleep
during the test, so it was not counted. On Linux,
`systemd-inhibit --what=idle:sleep <command>` keeps the machine awake
during a run; on macOS, `caffeinate -is <command>`.

**Scaling timeline** (run 1, from `watch-scaling.sh` and
`aws application-autoscaling describe-scaling-activities`):

| Time | Event | api-gateway | inventory | billing |
|------|-------|-------------|-----------|---------|
| 0 min | test start | 1 | 1 | 1 |
| 6.5 min | first scale-out (request count policy) | 3 | 1 | 1 |
| 7.5 min | peak task count | 4 | 1 | 1 |
| 17 min | load stops | 4 | 1 | 1 |
| 33.5 min | first scale-in (16.5 min after the load) | 3 | 1 | 1 |
| 42 min | back to 1 task (25 min after the load) | 1 | 1 | 1 |

Graphs of requests, running tasks, CPU and response time for both runs are
in [the monitoring module's README](../terraform/aymen/05-monitoring/README.md#screenshots).

Run 2 scaled out at the same points (3 tasks at 6 min, 4 at 7 min) and
was back to 1 task 29 min after the load stopped.

**CPU at each load level** (average per service, run 1):

| Load | api-gateway | inventory | billing |
|------|-------------|-----------|---------|
| idle | 1 task, 0 % | 1 task, 3 % | 1 task, 2 % |
| warm-up and ramp (20 to 50 req/s) | 1 task, 17 to 45 % | 1 task, 9 to 14 % | 1 task, 3 to 6 % |
| 60 req/s, before scale-out | 1 task, 59 to 68 % | 1 task, 22 to 26 % | 1 task, 6 to 7 % |
| 60 req/s, after scale-out | 4 tasks, about 16 % | 1 task, 26 to 36 % | 1 task, 7 % |

**Tuning decisions:**

- Only the gateway scaled out. It handles every request, so it reached
  the 60 % CPU target at 1 task. Inventory (36 % at most) and billing (7 %)
  never got near the target, so they correctly stayed at 1 task.
- Both scale-outs came from the request count policy (600 req/min per
  task), when the gateway's CPU was just reaching 60 %. That's what it is
  for: it adds tasks before CPU becomes the bottleneck. **Kept at 600.**
- At 60 req/s the request policy asks for 6 gateway tasks (3,600 req/min
  / 600), but the 4-task maximum was enough: with 4 tasks the gateway ran
  at about 16 % CPU and p95 stayed under 100 ms. **Kept the maximum at 4**
  to limit cost.
- Scale-in removes one task at a time and took 25 to 29 minutes to get
  back to 1 task. That is slow, but it avoids scaling in and out
  repeatedly when traffic drops for a short time, and the extra gateway
  tasks are small (0.25 vCPU). **Kept the cooldowns.**

## How to read the results

- **Scale-out works** if the task count goes up during the hold phase,
  the gateway's CPU drops once the new tasks start, and the failed rate
  and p95 latency stay under the thresholds.
- **Scale-in works** if every service goes back to 1 task some time after
  the test ends.
- If a service reaches its maximum while CPU is still above target, raise
  `autoscaling_max_capacity` or `task_cpu`. If it scales up and down
  repeatedly, raise the target or the cooldowns.
