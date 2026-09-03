locals {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket       = "hrryhomelab"
    key          = "infra/projects/torrent.tfstate"
    region       = local.region
    use_lockfile = true
    encrypt      = true
    kms_key_id   = "alias/terraform-state"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.15"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.11.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.3"
    }
  }
}

provider "aws" {
  profile = "terraform"
  region  = local.region
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

variable "cloudflare_token" {
  type = string
}

variable "cf_account_id" {
  type = string
}

variable "rpc_password" {
  type = string
}

variable "allow_ip" {
  type = list(string)
}

variable "dns" {
  type    = string
  default = "torrent"
}

locals {
  #ami  = "ami-085805cc0c5e13b11" # debian 12
  ami  = "ami-025f92b5a3f3b85dd" # ubuntu 24.04
  name = "torrents"
  tags = {
    Name        = local.name
    Provisioner = "Terraform"
  }
  ipv6 = false
}

module "key" {
  source   = "../../modules/ssh-key"
  keys_dir = "./keys"
  name     = "transmission"
}

output "ssh_private_key_file" {
  value = module.key.private_key_file
}
