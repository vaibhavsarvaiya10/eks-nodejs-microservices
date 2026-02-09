module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 20.0, < 21.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  enable_irsa = true

  # Enable both private and public endpoint access
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
}

# Note: aws-auth ConfigMap is configured manually using fix-eks-auth.ps1 script
# This avoids the chicken-egg problem where Kubernetes provider can't authenticate
# before aws-auth is created

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "vpc-cni"
  addon_version = data.aws_eks_addon_version.vpc_cni.version
  preserve      = true

  depends_on = [module.eks]
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = var.cluster_version
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.coredns.version
  preserve      = true

  depends_on = [module.eks]
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.cluster_version
}
