variable "name" {
  description = "Name of the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones for the VPC"
  type        = list(string)
}
