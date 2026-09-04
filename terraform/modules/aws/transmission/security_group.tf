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

module "transmission_security_group" {
  source            = "../../transmission-security-group"
  project_name      = var.project_name
  security_group_id = aws_security_group.main.id
  ipv6              = var.ipv6
}

locals {
  # TODO get this from the outputs of "transmission_security_group" module
  ephemeral_port_low  = 32768
  ephemeral_port_high = 60999
}

