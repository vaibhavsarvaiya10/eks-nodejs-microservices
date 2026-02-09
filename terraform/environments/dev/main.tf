module "vpc" {
  source = "../../modules/vpc"

  name = "eks-dev-vpc"
  azs  = ["ap-south-1a", "ap-south-1b"]
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = "eks-dev-cluster"
  cluster_version = "1.29"

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
}

module "alb_controller" {
  source = "../../modules/alb-controller"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  region            = var.region

  depends_on = [module.eks]
}

module "ecr_user" {
  source = "../../modules/ecr"

  name = "eks-dev-user-service"
}

module "ecr_order" {
  source = "../../modules/ecr"

  name = "eks-dev-order-service"
}
