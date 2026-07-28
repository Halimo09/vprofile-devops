variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "repositories" {
  description = "List of ECR repositories"
  type        = list(string)
}
