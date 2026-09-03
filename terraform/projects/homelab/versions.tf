terraform {
  backend "s3" {
    bucket       = "hrryhomelab"
    key          = "infra/projects/homelab.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
    kms_key_id   = "alias/terraform-state"
  }
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    github = {
      source  = "integrations/github"
      version = "5.13.0"
    }
    # https://registry.terraform.io/providers/grafana/grafana/latest/docs
    grafana = {
      source  = "grafana/grafana"
      version = "~> 1.36.1"
    }
  }
}
