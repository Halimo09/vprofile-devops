############################################
# Jenkins CI host (dedicated EC2 outside the cluster)
# Drop this file into terraform/live/dev/ - Terraform merges all .tf files
# in the directory, so main.tf does not need to change.
############################################

variable "admin_cidrs" {
  description = "CIDRs allowed to reach SSH / Jenkins UI / SonarQube. Set your own public IP as x.x.x.x/32."
  type        = list(string)
}

variable "jenkins_key_name" {
  description = "Existing EC2 key pair name. Set to null to use SSM Session Manager only."
  type        = string
  default     = null
}

variable "github_webhook_cidrs" {
  description = "GitHub hook ranges from https://api.github.com/meta - empty disables webhook ingress."
  type        = list(string)
  default     = []
}

module "jenkins" {
  source = "../../modules/jenkins"

  project_name = var.project_name
  environment  = var.environment

  vpc_id           = module.networking.vpc_id
  public_subnet_id = module.networking.public_subnet_ids[0]

  cluster_name  = module.eks.cluster_name
  app_namespace = "vprofile"

  key_name             = var.jenkins_key_name
  admin_cidrs          = var.admin_cidrs
  github_webhook_cidrs = var.github_webhook_cidrs

  install_sonarqube = true

  depends_on = [module.eks]
}

output "jenkins_url" {
  description = "Open this once the bootstrap finishes (2-4 minutes after apply)."
  value       = "http://${module.jenkins.public_ip}:8080"
}

output "sonarqube_url" {
  value = "http://${module.jenkins.public_ip}:9000"
}

output "jenkins_instance_id" {
  description = "aws ssm start-session --target <this>"
  value       = module.jenkins.instance_id
}

output "jenkins_role_arn" {
  description = "Already mapped into the cluster via an EKS access entry."
  value       = module.jenkins.role_arn
}
