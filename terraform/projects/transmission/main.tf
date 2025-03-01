terraform {
  backend "s3" {
    bucket         = "hrryhomelab"
    key            = "infra/projects/transmission.tfstate"
    region         = "us-west-2"
    dynamodb_table = "infra"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.88"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
}

variable "cloudflare_token" {
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
  region = "us-west-2"
  ami    = "ami-025f92b5a3f3b85dd" # ubuntu 24.04
  name   = "transmission-daemon"
}

provider "aws" {
  profile = "terraform"
  region  = local.region
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

module "key" {
  source   = "../../modules/ssh-key"
  keys_dir = "./keys"
  name     = "transmission"
}

resource "aws_key_pair" "key" {
  key_name   = "transmission-key"
  public_key = trimspace(module.key.public_key)
}

module "transmission" {
  source        = "../../modules/aws/transmission"
  project_name  = local.name
  rpc-password  = var.rpc_password
  rpc-whitelist = concat(["127.0.0.1"], var.allow_ip)
  blocklist-url = "http://list.iblocklist.com/?list=ydxerpxkpcfqjaybcssw&fileformat=p2p&archiveformat=gz"
  key_name      = aws_key_pair.key.key_name
  vpc_id        = aws_vpc.vpc.id
  ami           = local.ami
  # d3en.xlarge gives the lowest price with at least 3 terabytes of builtin storage.
  #
  # https://instances.vantage.sh/aws/ec2/d3en.xlarge?min_storage=3000&selected=d3en.xlarge
  #instance_type = "d3en.xlarge"
  # t4g.micro is small with high network throughput. Use t3a.micro for x86_64
  #
  # https://instances.vantage.sh/?region=us-west-2&selected=t4g.micro
  instance_type        = "t4g.micro" # 1GiB, 2vcpu burst, 5 Gib net
  instance_volume_size = 4657        # 5.00041 terabytes
  public_subnet_id     = aws_subnet.public.id
  ssh_user             = "ubuntu"
  public_key_openssh   = module.key.public_key
  private_key_openssh  = module.key.private_key
}

data "cloudflare_zone" "hrry_dev" {
  filter = {
    name = "hrry.dev"
  }
}

resource "cloudflare_dns_record" "dns" {
  zone_id = data.cloudflare_zone.hrry_dev.zone_id
  type    = "A"
  name    = var.dns
  content = module.transmission.public_ip
  proxied = false
  ttl     = 60
}

# Use with https://github.com/rndusr/stig
resource "local_file" "stigrc" {
  content  = module.transmission.stigrc
  filename = "./stigrc"
}

output "zone_id" {
  value = data.cloudflare_zone.hrry_dev.zone_id
}

output "ip" {
  value = module.transmission.public_ip
}

output "auth" {
  value = module.transmission.auth
}
