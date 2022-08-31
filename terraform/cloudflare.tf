provider "cloudflare" {
  api_token = var.cloudflare_token
}

data "cloudflare_zones" "hrry_me" {
  filter { name = "hrry.me" }
}

data "cloudflare_zones" "hrry_dev" {
  filter { name = "hrry.dev" }
}

data "cloudflare_zones" "harrybrwn_com" {
  filter { name = "harrybrwn.com" }
}

resource "cloudflare_zone" "hryb_dev" {
  account_id = var.cloudflare_account_id
  zone = "hryb.dev"
}

resource "cloudflare_record" "homelab_gateway_harrybrwn" {
  zone_id = data.cloudflare_zones.harrybrwn_com.zones[0].id
  name    = "_homelab"
  value   = var.gateway_ip
  proxied = true
  type    = "A"
  ttl     = 1 # proxied records require ttl of 1
}

resource "cloudflare_record" "homelab_gateway_hrrydev" {
  zone_id = data.cloudflare_zones.hrry_dev.zones[0].id
  name    = "_homelab"
  value   = var.gateway_ip
  type    = "A"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "hrry_dev_dns" {
  for_each = toset([
    "files",
    "gopkg",
    "hooks",
    "ip",
    "registry",
    "grafana",
    "s3-console",
    "s3",
  ])
  name    = each.key
  value   = "_homelab.hrry.dev"
  type    = "CNAME"
  proxied = true
  ttl     = 1 # proxied records require ttl of 1
  zone_id = data.cloudflare_zones.hrry_dev.zones[0].id
}