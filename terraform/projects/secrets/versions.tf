terraform {
  required_version = ">= 1.6"
  backend "s3" {
    bucket       = "hrryhomelab"
    key          = "infra/projects/homelab-secrets.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
    kms_key_id   = "alias/terraform-state"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
