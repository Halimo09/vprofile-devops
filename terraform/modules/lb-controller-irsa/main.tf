locals {
  name      = "${var.project_name}-${var.environment}"
  oidc_host = replace(var.oidc_issuer_url, "https://", "")
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "lb_controller" {
  name        = "${local.name}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for the AWS Load Balancer Controller (IRSA)"
  policy      = file("${path.module}/iam_policy.json")

  tags = local.tags
}

data "aws_iam_policy_document" "lb_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${local.name}-lb-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}
