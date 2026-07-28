output "vpc_id" {
  value = module.networking.vpc_id
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "node_group_name" {
  value = module.eks.node_group_name
}

output "lb_controller_role_arn" {
  value = module.lb_controller_irsa.role_arn
}
