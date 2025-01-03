# Cloudflare Variables

variable "cloudflare_token" {
  type = string
}

variable "cf_account_id" {
  type = string
}

variable "r2_access_key_id" {
  description = "Cloudflare R2 accesss key ID."
  type        = string
}

variable "r2_secret_access_key" {
  description = "Cloudflare R2 secret accesss key."
  type        = string
}

# DNS Variables

variable "gateway_ip" {
  description = "IP address of the main gateway."
  type        = string
}

variable "private_gateway_ip" {
  description = "Private IP address of the main gateway."
  type        = string
}

variable "staging_ip" {
  description = "Local IP address of staging environment's gateway machine."
  type        = string
}

variable "private_ip" {
  description = "Local IP address of staging environment's gateway machine."
  type        = string
}

variable "destination_email" {
  description = "Email to route custom domain emails to."
  type        = string
}

variable "tanya_destination_email" {
  type = string
}

variable "postgres_password" {
  type = string
}

variable "gh_pages_domain_verify_codes" {
  type = object({
    h3y_sh  = string
    hrry_me = string
  })
}

variable "sendgrid_verify" {
  type = map(object({
    id        = string
    subdomain = string
  }))
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}
