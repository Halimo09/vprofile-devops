output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}

output "namespace" {
  value = kubernetes_namespace.monitoring.metadata[0].name
}
