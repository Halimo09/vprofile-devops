############################################
# Default StorageClass
# Nothing in this repo ever created one - the database chart (and now
# Prometheus/Alertmanager/Grafana) reference `storageClassName: gp3`,
# but a fresh EKS 1.33 cluster ships with none. Managing it here means
# `terraform apply` alone is enough; no manual `kubectl apply` step.
############################################

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  reclaim_policy      = "Delete"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks]
}
