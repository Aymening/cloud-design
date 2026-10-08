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

# Push plain single-platform images: Amazon Inspector can't scan an image
# index, and then the tag shows no findings. Docker (buildx) wraps the image
# in an index with a provenance attestation unless it's turned off. Podman's
# default OCI format drops the Dockerfile HEALTHCHECK, so it uses the docker
# format.
build_help=$(docker build --help 2>&1)
if grep -- '--provenance' <<<"$build_help" >/dev/null; then
  build_flags="--provenance=false"
elif grep -- '--format' <<<"$build_help" >/dev/null; then
  build_flags="--format docker"
else
  build_flags=""
fi

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
    # $build_flags is left unquoted on purpose: "--format docker" is two words.
    docker build --platform linux/amd64 $build_flags -f "Dockerfiles/$image/Dockerfile" -t "$uri" . </dev/null
    docker push "$uri" </dev/null
  done

echo
echo "All images pushed with tag '$tag'."
