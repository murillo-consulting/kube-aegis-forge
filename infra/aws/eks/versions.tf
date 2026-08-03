terraform {
  required_version = "= 1.12.5"

  backend "s3" {
    region       = "eu-west-3"
    key          = "eks/kube-aegis-forge.tfstate"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.57.1"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

