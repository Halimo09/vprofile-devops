variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  description = "Public subnet for the Jenkins host - it needs outbound internet and an inbound UI."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster the pipeline deploys to."
  type        = string
}

variable "app_namespace" {
  description = "Namespace the Jenkins role is allowed to manage."
  type        = string
  default     = "vprofile"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH. Leave null to rely on SSM Session Manager only."
  type        = string
  default     = null
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach SSH / Jenkins UI / SonarQube. Use your own public IP as x.x.x.x/32."
  type        = list(string)
}

variable "github_webhook_cidrs" {
  description = <<-EOT
    CIDRs allowed to POST to the Jenkins UI for webhooks. GitHub publishes its
    hook ranges at https://api.github.com/meta (the "hooks" array).
    Leave empty to disable webhook ingress and use SCM polling instead.
  EOT
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = <<-EOT
    m7i-flex.large (2 vCPU / 8 GiB) - same family as the EKS node group. Enough
    headroom for Jenkins, a Maven-in-Docker build and SonarQube on one host.
    Do not drop below t3.large if SonarQube stays on this instance.
  EOT
  type        = string
  default     = "m7i-flex.large"
}

variable "root_volume_size" {
  description = "Docker layers, the Maven cache, the Trivy DB and SonarQube data add up quickly."
  type        = number
  default     = 50
}

variable "install_sonarqube" {
  description = <<-EOT
    Run SonarQube as a container on this host. Fine on m7i-flex.large; set to
    false if you move the instance to anything smaller than t3.large.
  EOT
  type        = bool
  default     = true
}

variable "sonarqube_version" {
  type    = string
  default = "10.7-community"
}

variable "swap_size_gb" {
  description = "Swapfile size in GiB. Not needed with 8 GiB of RAM - set above 0 only if you downsize the instance."
  type        = number
  default     = 0
}

variable "jenkins_max_heap_mb" {
  description = "Cap on the Jenkins JVM heap so docker builds, maven and SonarQube still have room."
  type        = number
  default     = 2048
}

variable "kubectl_version" {
  description = "Stay within one minor version of the EKS control plane."
  type        = string
  default     = "v1.33.0"
}

variable "trivy_version" {
  type    = string
  default = "0.58.1"
}

variable "maven_version" {
  type    = string
  default = "3.9.9"
}
