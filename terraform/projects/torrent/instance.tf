resource "aws_vpc" "vpc" {
  cidr_block                       = "10.0.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = true
  tags = {
    Name        = "${local.name}-vpc"
    Provisioner = "Terraform"
  }
}

resource "aws_key_pair" "key" {
  key_name   = "transmission-key"
  public_key = trimspace(module.key.public_key)
}

resource "aws_eip" "ip" {
  domain = "vpc"
  tags   = local.tags
}

# data "aws_availability_zones" "available" {
#   state = "available"
# }

locals {
  volume_device_name = "/dev/sdf"
  volume_mount_path  = "/mnt/torrents"
}

resource "aws_instance" "main" {
  # count                  = 1 # change to 0 for debugging
  ami = local.ami
  #availability_zone = data.aws_availability_zones.available.names[0]
  instance_type = "t4g.micro" # 1GiB, 2vcpu burst, 5 Gib net
  # subnet_id              = var.public_subnet_id
  subnet_id          = aws_subnet.public.id
  ipv6_address_count = local.ipv6 ? 1 : 0
  # key_name               = var.key_name
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  # We want to allow the destination address to not match the instance since
  # this is a VPN so we disable the `source_dest_check` attribute.
  source_dest_check = false
  tags              = local.tags

  user_data = templatefile("scripts/auto-mount.sh", {
    device_name = local.volume_device_name
    mount_point = local.volume_mount_path
  })

  root_block_device {
    encrypted = false
    tags      = local.tags
    # TODO attach another volume
    #volume_type = "gp2"
    #volume_size           = 37252.902984619 # 5TB
    #delete_on_termination = true
    volume_type = "gp2"
    # Volume Size in GB
    #volume_size = 4657 # 5.00041 terabytes
    volume_size = 8
  }
}

resource "aws_ebs_volume" "storage" {
  size = 128 # size in GB
  #type = "gp2"
  #type = "sc1"
  type = "st1"
  #availability_zone = data.aws_availability_zones.available.names[0]
  availability_zone = aws_instance.main.availability_zone
  tags = merge(local.tags, {
    Name = "${local.name}-storage-volume"
  })
}

resource "aws_volume_attachment" "ebs_att" {
  # See https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html
  device_name = local.volume_device_name
  volume_id   = aws_ebs_volume.storage.id
  instance_id = aws_instance.main.id
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.ip.id
}

module "transmission-init" {
  source       = "../../modules/transmission-init"
  project_name = local.name
  # public_ip       = aws_instance.main.public_ip
  public_ip       = aws_eip.ip.public_ip
  ssh_user        = "ubuntu"
  ssh_private_key = trimspace(module.key.private_key)
  rpc-password    = var.rpc_password
  rpc-whitelist   = concat(["127.0.0.1"], var.allow_ip)
  blocklist-url   = "http://list.iblocklist.com/?list=ydxerpxkpcfqjaybcssw&fileformat=p2p&archiveformat=gz"
  speed-limit-up  = 128 # kB/s to keep network costs down
  ratio-limit     = 0.15
  download-dir    = local.volume_mount_path
  depends_on = [
    aws_instance.main,
    aws_eip.ip,
    aws_volume_attachment.ebs_att,
  ]
}

resource "null_resource" "add_ssh_keys" {
  triggers = {
    user            = "ubuntu"
    port            = 22
    public_ip       = aws_eip.ip.public_ip
    ssh_private_key = trimspace(module.key.private_key)
  }
  depends_on = [
    aws_instance.main,
    aws_eip.ip,
    aws_volume_attachment.ebs_att,
    module.transmission-init,
  ]
  connection {
    type        = "ssh"
    user        = self.triggers.user
    port        = self.triggers.port
    host        = self.triggers.public_ip
    private_key = self.triggers.ssh_private_key
  }
  provisioner "remote-exec" {
    inline = concat(
      [
        "curl -fsSL https://github.com/harrybrwn.keys >> ~/.ssh/authorized_keys",
      ],
    )
  }
}

# module "smb-server" {
#   source          = "../../modules/smb-server"
#   ssh_user        = "ubuntu"
#   ssh_private_key = trimspace(module.key.private_key)
#   public_ip       = aws_eip.ip.public_ip
#   share_name      = "torrents"
#   path            = "/var/lib/transmission-daemon/downloads"
#   browsable       = true
#   read_only       = false
# }

# Use with https://github.com/rndusr/stig
resource "local_file" "stigrc" {
  content  = module.transmission-init.stigrc
  filename = "./stigrc"
}

output "auth" {
  value     = module.transmission-init.auth
  sensitive = true
}

output "ip" {
  value = aws_eip.ip.public_ip
}
