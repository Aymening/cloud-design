#!/bin/bash
# Builds the four app images and pushes them to the ECR repositories created
# by terraform/houda/ecr. Works with docker or podman (podman's docker alias).
#
# Usage: scripts/push-images.sh [tag]      (default tag: latest)
set -euo pipefail
cd "$(dirname "$0")/.."

tag="${1:-latest}"
ecr_dir=terraform/houda/ecr

registry=$(terraform -chdir="$ecr_dir" output -raw registry)
# <account>.dkr.ecr.<region>.amazonaws.com
region=$(echo "$registry" | cut -d. -f4)

echo "Logging in to $registry..."
aws ecr get-login-password --region "$region" |
  docker login --username AWS --password-stdin "$registry"

terraform -chdir="$ecr_dir" output -json repository_urls |
  python3 -c 'import json, sys; [print(name, url) for name, url in json.load(sys.stdin).items()]' |
  while read -r image repository_url; do
    uri="$repository_url:$tag"
    echo
    echo "=== $image -> $uri"
    # Fargate runs x86_64 tasks (see runtime_platform in the task definitions).
    docker build --platform linux/amd64 -f "Dockerfiles/$image/Dockerfile" -t "$uri" . </dev/null
    docker push "$uri" </dev/null
  done

echo
echo "All images pushed with tag '$tag'."
