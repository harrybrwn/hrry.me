data "cloudflare_zones" "all" {
  status    = "active"
  direction = "desc"
}

locals {
  zones = { for z in data.cloudflare_zones.all.result : replace(z.name, ".", "_") => z.id }
}

resource "cloudflare_dns_record" "dns" {
  zone_id = local.zones.hrry_dev
  name    = "torrents"
  content = aws_eip.ip.public_ip
  type    = "A"
  ttl     = 60
  proxied = false
  comment = "Created by terraform."
}
