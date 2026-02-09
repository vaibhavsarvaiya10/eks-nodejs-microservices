output "policy_arn" {
  description = "ARN of the ALB controller IAM policy"
  value       = aws_iam_policy.alb_controller.arn
}

output "policy_name" {
  description = "Name of the ALB controller IAM policy"
  value       = aws_iam_policy.alb_controller.name
}
