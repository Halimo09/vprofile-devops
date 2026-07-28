variable "project_name" {
  type        = string
  description = "Project name"
  default     = "vprofile"
}

variable "environment" {
  type        = string
  description = "Environment"
  default     = "dev"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "eu-central-1"
}

variable "owner" {
  type        = string
  description = "Infrastructure owner"
}
