variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "namespace" {
  type    = string
  default = "monitoring"
}

variable "storage_class" {
  description = "StorageClass used for Prometheus/Alertmanager/Grafana PVCs."
  type        = string
  default     = "gp3"
}

variable "retention" {
  description = "How long Prometheus keeps metrics on disk."
  type        = string
  default     = "10d"
}

variable "prometheus_storage_size" {
  type    = string
  default = "20Gi"
}

variable "grafana_storage_size" {
  type    = string
  default = "5Gi"
}

variable "alertmanager_storage_size" {
  type    = string
  default = "2Gi"
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the Grafana ALB. Reuses the same list as the Jenkins host."
  type        = list(string)
}

variable "grafana_host" {
  description = "Hostname for the Grafana Ingress. Use a real DNS name once you have one; otherwise keep the placeholder and access via a Host header or /etc/hosts entry pointed at the ALB's address."
  type        = string
  default     = "grafana.vprofile.local"
}

variable "chart_version" {
  description = "kube-prometheus-stack chart version. Pinned on purpose - bump deliberately. Check https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack for newer releases."
  type        = string
  default     = "86.1.0"
}
