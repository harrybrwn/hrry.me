provider "cloudflare" {
  api_token = var.cloudflare_token
}

data "cloudflare_zones" "all" {
  filter {
    account_id = var.cf_account_id
    status     = "active"
  }
}

locals {
  zones = { for z in data.cloudflare_zones.all.zones : replace(z.name, ".", "_") => z.id }
}

# homelab's gateway DNS records
resource "cloudflare_record" "homelab_gateway" {
  for_each = toset([
    local.zones.harrybrwn_com,
    local.zones.hrry_dev,
    cloudflare_zone.hrry_io.id,
  ])
  zone_id = each.key
  name    = "_homelab"
  content = var.gateway_ip
  type    = "A"
  proxied = true
  ttl     = 1 # proxied records require ttl of 1
}

# Root DNS record for each main zones
resource "cloudflare_record" "root_dns" {
  for_each = toset([
    local.zones.harrybrwn_com,
    cloudflare_zone.hrry_io.id,
  ])
  zone_id = each.key
  name    = "@" # root domain only
  content = var.gateway_ip
  type    = "A"
  proxied = true
  ttl     = 1 # proxied records require ttl of 1
}

resource "cloudflare_email_routing_settings" "harrybrwn_com" {
  zone_id = local.zones.harrybrwn_com
  enabled = true
}

resource "cloudflare_email_routing_address" "tanya_email_destination" {
  account_id = var.cf_account_id
  email      = var.tanya_destination_email
}

resource "cloudflare_email_routing_rule" "harry" {
  for_each = toset(concat(
    [
      "cloudflare-notifications",
      # "harry",
      # "admin",
      "ynvybmvyigvtywlscg",
      "trash",
    ],
    flatten([for i in range(4) : "trash${i + 1}"])
  ))
  zone_id = local.zones.harrybrwn_com
  enabled = true
  name    = "cf email route ${each.key}"

  matcher {
    type  = "literal"
    field = "to"
    value = "${each.key}@harrybrwn.com"
  }

  action {
    type  = "forward"
    value = [var.destination_email]
  }
}
