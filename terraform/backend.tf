terraform {
  backend "s3" {
    bucket = "eks-terraform-state-demo"
    key    = "dev/eks.tfstate"
    region = "ap-south-1"
    encrypt = true
  }
}
