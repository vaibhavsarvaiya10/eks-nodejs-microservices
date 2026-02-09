variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "policy_arns" {
  description = "List of policy ARNs to attach"
  type        = list(string)
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "service_account" {
  description = "Kubernetes service account name"
  type        = string
}
