resource "random_password" "grafana_admin" {
  length  = 20
  special = false # keep it simple to paste into a browser prompt
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  # helm_release with a `values` block instead of dozens of `set{}` entries -
  # one readable YAML document instead of scattered flags. Easier to diff,
  # easier to extend.
  values = [
    yamlencode({
      fullnameOverride = "kps"

      prometheus = {
        prometheusSpec = {
          retention = var.retention
          # Without these three, the operator ONLY picks up ServiceMonitors /
          # PodMonitors / PrometheusRules created by this same helm release.
          # The app chart's own ServiceMonitor would be silently ignored.
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false
          resources = {
            requests = { cpu = "250m", memory = "512Mi" }
            limits   = { cpu = "1", memory = "1Gi" }
          }
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = { storage = var.prometheus_storage_size }
                }
              }
            }
          }
        }
      }

      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = { storage = var.alertmanager_storage_size }
                }
              }
            }
          }
        }
      }

      grafana = {
        adminPassword = random_password.grafana_admin.result
        persistence = {
          enabled          = true
          storageClassName = var.storage_class
          size             = var.grafana_storage_size
        }
        ingress = {
          enabled          = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme"        = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"   = "ip"
            "alb.ingress.kubernetes.io/listen-ports"  = "[{\"HTTP\": 80}]"
            "alb.ingress.kubernetes.io/inbound-cidrs" = join(",", var.admin_cidrs)
          }
          hosts = [var.grafana_host]
          path  = "/"
        }
      }

      # Node exporter + kube-state-metrics ship with the chart and are
      # enabled by default - CPU/memory/disk per node, pod/deployment/
      # PVC status, restarts, etc. for every workload in the cluster,
      # with zero changes needed in the app itself.
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}
