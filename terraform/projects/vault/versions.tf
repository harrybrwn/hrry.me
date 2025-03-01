terraform {
  backend "s3" {
    bucket         = "hrryhomelab"
    key            = "infra/projects/vault.tfstate"
    region         = var.region
    dynamodb_table = "infra"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.88"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.0-pre1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
  }
}
