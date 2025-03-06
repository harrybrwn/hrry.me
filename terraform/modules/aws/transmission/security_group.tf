locals {
  ephemeral_port_low  = 32768
  ephemeral_port_high = 60999
}

resource "aws_security_group" "main" {
  name        = var.project_name
  description = "Allow inbound and outbound traffic."
  vpc_id      = var.vpc_id
  tags        = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.main.id
  ip_protocol       = "tcp"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  cidr_ipv4         = var.ipv6 ? null : var.ssh_cidr
  cidr_ipv6         = var.ipv6 ? var.ssh_cidr : null
  tags              = local.tags
}

# resource "aws_vpc_security_group_egress_rule" "egress_all" {
#   security_group_id = aws_security_group.main.id
#   ip_protocol       = -1
#   tags              = local.tags
#   cidr_ipv4         = var.ipv6 ? "" : var.ssh_cidr
#   tags = local.tags
# }

locals {
  ingress_port_pairs = [
    { from_port = var.rpc-port, to_port = var.rpc-port },
    { from_port = var.peer-port, to_port = var.peer-port },
    { from_port = local.ephemeral_port_low, to_port = local.ephemeral_port_high },
    { from_port = var.peer-port-random-low, to_port = var.peer-port-random-high },
  ]
  ingress_ports = flatten([
    for proto in ["tcp", "udp"] : [
      for pair in local.ingress_port_pairs : {
        from_port = pair.from_port
        to_port   = pair.to_port
        proto     = proto
      }
    ]
  ])
}

resource "aws_vpc_security_group_ingress_rule" "ingress" {
  for_each = tomap({
    for p in local.ingress_ports : "${p.proto}-${p.from_port}-${p.to_port}" => p
  })
  security_group_id = aws_security_group.main.id
  ip_protocol       = each.value.proto
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_ipv4         = "0.0.0.0/0"
  cidr_ipv6         = var.ipv6 ? "::/0" : null
  tags              = local.tags
}

locals {
  # Found with transmission-remote -t all -it | grep -P 'Tracker \d+:' | awk '{print $3}' | cut -d: -f2 | sort | uniq | copy
  tracker_ports = flatten([
    [
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
    ],
  ])
  egress_port_pairs = flatten([
    [for p in local.tracker_ports : { from_port = p, to_port = p }],
    [
      # https://superuser.com/questions/1706564/which-ports-need-to-be-allowed-through-firewall-to-seed-torrent-using-transmissi
      { from_port = 6881, to_port = 6889 },
      { from_port = var.peer-port-random-low, to_port = var.peer-port-random-high },
      { from_port = local.ephemeral_port_low, to_port = local.ephemeral_port_high },
    ]
  ])
  tracker_protos = ["tcp", "udp"]
  trackers = flatten([
    for proto in local.tracker_protos : [
      for pair in local.egress_port_pairs : {
        from_port = pair.from_port
        to_port   = pair.to_port
        proto     = proto
      }
    ]
  ])
}

resource "aws_vpc_security_group_egress_rule" "tracker_egress" {
  for_each = tomap({
    for tr in local.trackers : "${tr.proto}-${tr.from_port}-${tr.to_port}" => tr
  })
  security_group_id = aws_security_group.main.id
  ip_protocol       = each.value.proto
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_ipv4         = "0.0.0.0/0"
  cidr_ipv6         = var.ipv6 ? "::/0" : null
  tags              = local.tags
}
