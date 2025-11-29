resource "aws_security_group" "main" {
  name        = local.name
  description = "Allow inbound and outbound traffic."
  vpc_id      = aws_vpc.vpc.id
  tags        = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.main.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  #cidr_ipv4         = var.ipv6 ? null : var.ssh_cidr
  #cidr_ipv6         = var.ipv6 ? var.ssh_cidr : null
  cidr_ipv4 = "0.0.0.0/0"
  cidr_ipv6 = null
  tags      = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "icmp" {
  security_group_id = aws_security_group.main.id
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  #cidr_ipv4         = var.ipv6 ? null : var.ssh_cidr
  #cidr_ipv6         = var.ipv6 ? var.ssh_cidr : null
  cidr_ipv4 = "0.0.0.0/0"
  cidr_ipv6 = null
  tags      = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "smb" {
  for_each          = toset(["445", "139"])
  security_group_id = aws_security_group.main.id
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
  #cidr_ipv4         = var.ipv6 ? null : var.ssh_cidr
  #cidr_ipv6         = var.ipv6 ? var.ssh_cidr : null
  cidr_ipv4 = "0.0.0.0/0"
  cidr_ipv6 = null
  tags      = local.tags
}

# resource "aws_vpc_security_group_ingress_rule" "smb_udp" {
#   for_each          = toset(["445", "139"])
#   security_group_id = aws_security_group.main.id
#   ip_protocol       = "udp"
#   from_port         = tonumber(each.key)
#   to_port           = tonumber(each.key)
#   #cidr_ipv4         = var.ipv6 ? null : var.ssh_cidr
#   #cidr_ipv6         = var.ipv6 ? var.ssh_cidr : null
#   cidr_ipv4 = "0.0.0.0/0"
#   cidr_ipv6 = null
#   tags      = local.tags
# }

module "transmission_security_group" {
  source            = "../../modules/transmission-security-group"
  project_name      = local.name
  security_group_id = aws_security_group.main.id
  ipv6              = local.ipv6
}
