############################################
# Jenkins module - main.tf
# Dedicated CI/CD host outside the cluster:
#   - EC2 in a public subnet (AL2023)
#   - IAM role: ECR push, eks:DescribeCluster, SSM
#   - EKS access entry scoped to the vprofile namespace
############################################

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------------- security group
resource "aws_security_group" "jenkins" {
  name        = "${local.name}-jenkins-host-sg"
  description = "Jenkins CI host"
  vpc_id      = var.vpc_id

  # SSH - restrict to your own IP via var.admin_cidrs
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  ingress {
    description = "SonarQube UI"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
  }

  # Sonar and Jenkins are co-located on this same instance. The webhook
  # SonarQube fires back to Jenkins after each analysis travels out via the
  # instance's private IP - SonarQube rejects localhost/loopback URLs as an
  # SSRF guard, so private-IP is the only option. Belt-and-suspenders: don't
  # rely on undocumented same-instance SG behavior, allow it explicitly.
  ingress {
    description = "Jenkins webhook receiver (self - SonarQube runs on the same host)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
  }

  # GitHub webhook delivery. Empty list = webhooks disabled (use SCM polling).
  dynamic "ingress" {
    for_each = length(var.github_webhook_cidrs) > 0 ? [1] : []
    content {
      description = "GitHub webhooks"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = var.github_webhook_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-jenkins-host-sg" })
}

# ---------------------------------------------------------------- IAM role
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${local.name}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

# Push and pull images in ECR.
resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Session Manager access - lets you open a shell without an SSH key.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Only what `aws eks update-kubeconfig` needs. Authorisation inside the
# cluster comes from the access entry below, not from IAM.
data "aws_iam_policy_document" "eks_describe" {
  statement {
    effect    = "Allow"
    actions   = ["eks:DescribeCluster", "eks:ListClusters"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "eks_describe" {
  name   = "${local.name}-jenkins-eks-describe"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.eks_describe.json
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${local.name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
  tags = local.tags
}

# ---------------------------------------------------------------- EKS access
# Maps the Jenkins IAM role to a Kubernetes identity with edit rights on the
# application namespace only - no cluster-admin for CI.
resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  type          = "STANDARD"
  tags          = local.tags
}

resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.app_namespace]
  }

  depends_on = [aws_eks_access_entry.jenkins]
}

# ---------------------------------------------------------------- instance
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh", {
    kubectl_version     = var.kubectl_version
    trivy_version       = var.trivy_version
    maven_version       = var.maven_version
    install_sonarqube   = var.install_sonarqube
    sonarqube_version   = var.sonarqube_version
    swap_size_gb        = var.swap_size_gb
    jenkins_max_heap_mb = var.jenkins_max_heap_mb
  })

  # Replace the instance when the bootstrap script changes.
  user_data_replace_on_change = true

  # AWS republishes a new al2023 AMI every few weeks. Without this, every
  # `terraform apply` re-resolves data.aws_ssm_parameter.al2023_ami to
  # whatever is newest that day, sees a diff against state, and destroys +
  # recreates this instance - wiping Jenkins and SonarQube in the process.
  # Ignoring drift here means the instance keeps running on the AMI it was
  # created with; to deliberately roll it onto a newer AMI later, remove
  # this block for one apply (or `terraform taint` the resource).
  lifecycle {
    ignore_changes = [ami]
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  tags = merge(local.tags, { Name = "${local.name}-jenkins" })
}
