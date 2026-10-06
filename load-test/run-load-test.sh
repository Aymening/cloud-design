#!/bin/bash
# Runs k6-script.js against the deployed app. k6 runs in a container, so it
# doesn't need to be installed. The console output is also saved under
# load-test/results/.
#
# Usage: load-test/run-load-test.sh            (peak: 60 requests/second)
#        PEAK_RPS=120 load-test/run-load-test.sh
# Watch scaling at the same time from a second terminal:
#        load-test/watch-scaling.sh
set -euo pipefail
cd "$(dirname "$0")/.."

export BASE_URL ACCESS_TOKEN PEAK_RPS="${PEAK_RPS:-60}"
BASE_URL=$(terraform -chdir=terraform/houda/platform output -raw app_url)
ACCESS_TOKEN=$(scripts/get-token.sh)

mkdir -p load-test/results
output="load-test/results/k6-$(date +%Y%m%d-%H%M%S)-${PEAK_RPS}rps.txt"

echo "Target: $BASE_URL  peak: $PEAK_RPS req/s  output: $output"
# "-e NAME" without a value passes the variable through, so the token isn't
# visible in the process list.
docker run --rm -i -e BASE_URL -e ACCESS_TOKEN -e PEAK_RPS \
  docker.io/grafana/k6:latest run - <load-test/k6-script.js | tee "$output"
