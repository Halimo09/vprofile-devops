variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS cluster's IAM OIDC provider (from the eks module)"
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL of the EKS cluster, e.g. https://oidc.eks.<region>.amazonaws.com/id/XXXX"
}

variable "namespace" {
  type    = string
  default = "kube-system"
}

variable "service_account_name" {
  type    = string
  default = "aws-load-balancer-controller"
}
