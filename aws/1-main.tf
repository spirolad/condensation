terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  //backend "http" {}
}

provider "aws" {
  region = var.aws_region
  default_tags {
   tags = {
      Version     = var.app_version
      User        = var.user
      Commit      = var.commit
      Branch      = var.branch
      Environment = var.environment
      Terraform   = "true"
   }
 }

}

