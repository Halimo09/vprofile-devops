module "networking" {
  source       = "../../modules/networking"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment

  cluster_name       = "${var.project_name}-${var.environment}-eks"
  kubernetes_version = var.kubernetes_version

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  cluster_security_group_id = module.networking.eks_security_group_id

  cluster_role_arn    = module.iam.eks_cluster_role_arn
  node_group_role_arn = module.iam.node_group_role_arn
}
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repositories = [
    "app",
    "database",
    "rabbitmq",
    "memcached"
  ]
}

module "lb_controller_irsa" {
  source = "../../modules/lb-controller-irsa"

  project_name = var.project_name
  environment  = var.environment

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.networking.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_controller_irsa.role_arn
  }

  depends_on = [
    module.eks,
    module.lb_controller_irsa
  ]
}
