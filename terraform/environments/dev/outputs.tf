output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "ecr_user_repository_url" {
  description = "URL of the user service ECR repository"
  value       = module.ecr_user.repository_url
}

output "ecr_order_repository_url" {
  description = "URL of the order service ECR repository"
  value       = module.ecr_order.repository_url
}
