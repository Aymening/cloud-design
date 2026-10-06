output "repository_urls" {
  description = "Image repository URL per image name (append :<tag> to get an image URI)"
  value       = { for image, repo in aws_ecr_repository.this : image => repo.repository_url }
}

output "registry" {
  description = "Registry host to `docker login` against"
  value       = split("/", values(aws_ecr_repository.this)[0].repository_url)[0]
}

output "rabbit_queue_image" {
  description = "Value for container_image in terraform/aymen/04-messaging"
  value       = "${aws_ecr_repository.this["rabbit-queue"].repository_url}:latest"
}
