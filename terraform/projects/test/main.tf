terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.88"
    }
  }
}

locals {
  tracker_ports = [
    1337,
    2095,
    2710,
    2810,
    2920,
    443,
    451,
    6699,
    6969,
    80,
  ]
  tracker_protos = ["tcp", "udp"]
  # { for port in local.tracker_ports : [ for proto in local.tracker_protos : "${proto}-${port}" => port ] }
  trackers = flatten([
    for proto in local.tracker_protos : [
      for port in local.tracker_ports : {
        port  = port
        proto = proto
      }
    ]
  ])
  region = "us-west-2"
}

provider "aws" {
  profile = "terraform"
  region  = local.region
}

data "aws_caller_identity" "current" {}

data "aws_ami" "example" {
  # executable_users = [
  #   # "self",
  #   data.aws_caller_identity.current.id,
  # ]
  most_recent = true
  # name_regex       = "^myami-[0-9]{3}"
  owners = [
    "self",
    "amazon",
    "aws-marketplace",
  ]

  # filter {
  #   name   = "name"
  #   values = ["myami-*"]
  # }

  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  # filter {
  #   name   = "Platform"
  #   values = ["Linux/UNIX"]
  # }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "image-type"
    values = ["machine"]
  }
}
