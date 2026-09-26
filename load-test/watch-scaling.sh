#!/bin/bash
# Every 30 seconds, prints each app service's desired/running task count and
# its average CPU over the last minute, and appends it to a file under
# load-test/results/. Run it next to run-load-test.sh; stop with Ctrl+C.
set -euo pipefail
cd "$(dirname "$0")/.."

cluster=$(terraform -chdir=terraform/houda/platform output -raw cluster_name)
services=(api-gateway-service inventory-service billing-service)

mkdir -p load-test/results
output="load-test/results/scaling-$(date +%Y%m%d-%H%M%S).txt"
echo "Saving to $output"

printf '%-8s  %-20s %7s %7s %6s\n' time service desired running cpu% | tee "$output"
while true; do
  now=$(date +%H:%M:%S)
  aws ecs describe-services --cluster "$cluster" --services "${services[@]}" \
    --query 'services[].[serviceName,desiredCount,runningCount]' --output text |
    while read -r service desired running; do
      cpu=$(aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization \
        --dimensions Name=ClusterName,Value="$cluster" Name=ServiceName,Value="$service" \
        --start-time "$(date -u -d '-3 minutes' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
        --period 60 --statistics Average \
        --query 'sort_by(Datapoints, &Timestamp)[-1].Average' --output text </dev/null)
      [ "$cpu" = "None" ] || cpu=$(printf '%.0f' "$cpu")
      printf '%-8s  %-20s %7s %7s %6s\n' "$now" "$service" "$desired" "$running" "$cpu"
    done | tee -a "$output"
  sleep 30
done
