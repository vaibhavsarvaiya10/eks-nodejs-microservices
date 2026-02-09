resource "aws_iam_policy" "alb_controller" {
  name = "AWSLoadBalancerControllerPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elbv2:CreateLoadBalancer",
          "elbv2:CreateTargetGroup",
          "elbv2:DescribeLoadBalancers",
          "elbv2:DescribeTargetGroups",
          "elbv2:DescribeLoadBalancerAttributes",
          "elbv2:Listeners",
          "elbv2:DescribeListeners",
          "elbv2:ModifyLoadBalancerAttributes",
          "elbv2:ModifyTargetGroup",
          "elbv2:ModifyTargetGroupAttributes",
          "elbv2:DeleteLoadBalancer",
          "elbv2:DeleteTargetGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      }
    ]
  })
}
