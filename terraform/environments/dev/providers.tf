provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  # Let it inherit from kubernetes provider
  # No nested kubernetes block needed
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
