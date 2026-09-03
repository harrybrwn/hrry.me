terraform {
  # backend "s3" {
  #   bucket       = "hrryhomelab"
  #   key          = "infra/projects/hrry.me.tfstate"
  #   region       = "us-west-2"
  #   use_lockfile = true
  #   encrypt      = true
  #   kms_key_id   = "alias/terraform-state"
  # }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    # https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.52"
    }
    github = {
      source  = "integrations/github"
      version = "5.13.0"
    }
    # https://registry.terraform.io/providers/grafana/grafana/latest/docs
    grafana = {
      source  = "grafana/grafana"
      version = "~> 1.27.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = var.aws_region
}

provider "github" {}

provider "grafana" {
  url  = "https://grafana.hrry.dev"
  auth = ""
}
