output "eks_cluster_role_arn" {
  description = "IAM Role ARN for the EKS Cluster"

  value = aws_iam_role.eks_cluster.arn
}

output "node_group_role_arn" {
  description = "IAM Role ARN for the EKS Worker Nodes"

  value = aws_iam_role.node_group.arn
}

output "node_instance_profile_name" {
  description = "Instance Profile Name for EKS Worker Nodes"

  value = aws_iam_instance_profile.node_group.name
}

output "node_instance_profile_arn" {
  description = "Instance Profile ARN for EKS Worker Nodes"

  value = aws_iam_instance_profile.node_group.arn
}