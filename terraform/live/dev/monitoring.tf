############################################
# Monitoring: kube-prometheus-stack (Prometheus + Alertmanager + Grafana)
# Drop this file into terraform/live/dev/ - Terraform merges all .tf files
# in the directory, so main.tf does not need to change.
############################################

module "monitoring" {
  source = "../../modules/monitoring"

  project_name = var.project_name
  environment  = var.environment

  storage_class = "gp3"
  admin_cidrs   = var.admin_cidrs # reuses the same list you set for Jenkins

  depends_on = [
    module.eks,
    kubernetes_storage_class_v1.gp3
  ]
}

output "grafana_admin_password" {
  description = "terraform output -raw grafana_admin_password"
  value       = module.monitoring.grafana_admin_password
  sensitive   = true
}

output "grafana_access" {
  description = "Grafana has no real domain yet, so the ALB only responds to this Host header."
  value       = "kubectl get ingress -n monitoring kps-grafana   # then curl -H 'Host: grafana.vprofile.local' http://<ADDRESS>/"
}
