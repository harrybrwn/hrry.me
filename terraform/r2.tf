locals {
  r2_domain = "${var.cf_account_id}.r2.cloudflarestorage.com"
}

provider "aws" {
  alias      = "cloudflare"
  access_key = var.r2_access_key_id
  secret_key = var.r2_secret_access_key
  region     = "auto"
  endpoints {
    s3 = "https://${local.r2_domain}"
  }
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}

resource "aws_s3_bucket" "registry-bucket" {
  provider = aws.cloudflare
  bucket   = "container-registry"
}

# Public Files Bucket.

resource "aws_s3_bucket" "pub" {
  provider = aws.cloudflare
  bucket   = "pub"
}

resource "aws_s3_bucket_cors_configuration" "pub" {
  bucket   = aws_s3_bucket.pub.id
  provider = aws.cloudflare

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

