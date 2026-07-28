output "repository_urls" {
  description = "URLs of all ECR repositories"

  value = {
    for repo, resource in aws_ecr_repository.this :
    repo => resource.repository_url
  }
}
