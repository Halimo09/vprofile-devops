output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_arn" { value = aws_eks_cluster.this.arn }
output "node_group_name" { value = aws_eks_node_group.default.node_group_name }
output "cluster_certificate_authority_data" { value = aws_eks_cluster.this.certificate_authority[0].data }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.eks.arn }
output "oidc_issuer_url" { value = aws_eks_cluster.this.identity[0].oidc[0].issuer }
