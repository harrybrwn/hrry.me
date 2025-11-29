resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${local.name}-ig"
    Provisioner = "Terraform"
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.vpc.id
  #availability_zone = data.aws_availability_zones.available.names[0]
  # IPv4
  cidr_block              = "10.0.1.0/24" # TODO use "${cidrsubnet(aws_vpc.vpc.cidr_block, 4, 1)}" or something like it
  map_public_ip_on_launch = true
  # IPv6
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, 1)
  assign_ipv6_address_on_creation = true
  tags = {
    Name        = "${local.name}-public-subnet"
    Provisioner = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.ig.id
  }
  tags = {
    Name        = "${local.name}-public-route-table"
    Provisioner = "Terraform"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
