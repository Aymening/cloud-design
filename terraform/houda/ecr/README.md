# Image registry module (Task 6)

Creates the private ECR repositories that every ECS task pulls its image
from. It has no dependencies, so it is applied before anything that runs a
container, and the images are pushed right after.

## What this creates

- 4 ECR repositories: `cloud-design/api-gateway-app`, `cloud-design/inventory-app`,
  `cloud-design/billing-app`, `cloud-design/rabbit-queue` (the databases run
  on RDS, so they have no image)
- Amazon Inspector enabled for ECR, with enhanced continuous scanning on
  the `cloud-design/*` repositories: every pushed image is scanned, and
  re-checked whenever a new vulnerability affecting it is published
- A lifecycle policy per repository that keeps only the 5 most recent images

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform apply -var-file=terraform.tfvars

# then, from the repository root: build and push all four images
scripts/push-images.sh
```

`push-images.sh` logs in to the registry, builds each image from
`Dockerfiles/<image>/Dockerfile` with the repository root as build context,
and pushes it as `:latest` (or the tag given as first argument).

## Outputs

- `repository_urls`: map of image name to repository URL, read by
  `terraform/houda/platform` to build the task definitions' image URIs
- `registry`: registry host used by `docker login`
- `rabbit_queue_image`: the value to set as `container_image` in
  `terraform/aymen/04-messaging`

## Viewing scan results

```bash
# Findings for one image
aws ecr describe-image-scan-findings --repository-name cloud-design/api-gateway-app \
  --image-id imageTag=latest --query 'imageScanFindings.findingSeverityCounts'

# All findings for the project's images, most severe first
aws inspector2 list-findings --sort-criteria field=SEVERITY,sortOrder=DESC \
  --filter-criteria '{"ecrImageRepositoryName":[{"comparison":"PREFIX","value":"cloud-design/"}]}' \
  --query 'findings[].[severity,title]' --output table
```

The Inspector console (**Findings → By container image**) shows the same
results.

## Design notes

- `force_delete = true` so `terraform destroy` works even when the
  repositories still hold images; this project is torn down after testing.
- Tags are mutable so `:latest` can be re-pushed during development. Pushing
  a unique tag (e.g. the git commit) and setting `image_tag` in the platform
  module is the way to get repeatable deployments.
