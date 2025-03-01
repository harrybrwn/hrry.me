locals {
  tags = {
    Name        = "${var.project_name}"
    Provisioner = "Terraform"
  }
}

resource "aws_eip" "ip" {
  domain = "vpc"
  tags   = local.tags
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.ip.id
}

resource "aws_security_group" "main" {
  name        = var.project_name
  description = "Allow inbound and outbound traffic."

  vpc_id = var.vpc_id
  tags   = local.tags

  # Allow RPC traffic to the transmission-daemon.
  ingress {
    from_port        = var.rpc-port
    to_port          = var.rpc-port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = var.ipv6 ? ["::/0"] : []
  }

  # Allow incoming ssh traffic
  ingress {
    from_port        = var.ssh_port
    to_port          = var.ssh_port
    protocol         = "tcp"
    cidr_blocks      = [var.ssh_cidr]
    ipv6_cidr_blocks = var.ipv6 ? ["::/0"] : []
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = var.ipv6 ? ["::/0"] : []
  }
}

resource "aws_security_group_rule" "ingress_peer_port" {
  for_each          = toset(["tcp", "udp"])
  type              = "ingress"
  security_group_id = aws_security_group.main.id
  protocol          = each.key
  from_port         = var.peer-port
  to_port           = var.peer-port
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = var.ipv6 ? ["::/0"] : []
}

resource "aws_instance" "main" {
  # count                  = 1 # change to 0 for debugging
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  ipv6_address_count     = var.ipv6 ? 1 : 0
  key_name               = var.key_name
  vpc_security_group_ids = concat([aws_security_group.main.id], var.vpc_security_group_ids)
  # We want to allow the destination address to not match the instance since
  # this is a VPN so we disable the `source_dest_check` attribute.
  source_dest_check = false
  tags              = local.tags

  root_block_device {
    encrypted = false
    tags      = local.tags
    # TODO attach another volume
    #volume_type = "gp2"
    #volume_size           = 37252.902984619 # 5TB
    #delete_on_termination = true
    volume_type = "gp2"
    volume_size = var.instance_volume_size # Gib
  }
}

resource "aws_volume_attachment" "volumes" {
  for_each    = { for vol in var.instance_volumes : vol.device_name => vol.volume_id }
  instance_id = aws_instance.main.id
  volume_id   = each.value
  device_name = each.key
}

resource "null_resource" "install_daemon" {
  triggers = {
    user        = var.ssh_user
    port        = format("%d", var.ssh_port)
    private_key = var.private_key_openssh
    host        = aws_eip.ip.public_ip
  }
  depends_on = [aws_instance.main, aws_eip.ip]
  connection {
    type        = "ssh"
    user        = self.triggers.user
    port        = self.triggers.port
    private_key = self.triggers.private_key
    host        = self.triggers.host
  }
  provisioner "remote-exec" {
    inline = concat(
      [
        "sudo apt-get -y update",
        "sudo apt-get install -y transmission-daemon transmission-cli jq moreutils curl vim git software-properties-common unattended-upgrades",
        "sudo hostnamectl set-hostname ${aws_instance.main.tags["Name"]}",
        "echo 'net.core.rmem_max = 4194304' | sudo tee -a /etc/sysctl.conf",
        "echo 'net.core.wmem_max = 1048576' | sudo tee -a /etc/sysctl.conf",
        "sudo mkdir -p /etc/systemd/system/transmission-daemon.service.d",
      ],
      # if 'ipv6' is false then disable ipv6 on the machine
      var.ipv6 == false ? [
        "echo 'net.ipv6.conf.all.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf",
        "echo 'net.ipv6.conf.default.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf",
        "echo 'net.ipv6.conf.lo.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf",
      ] : [],
      [
        "sudo sysctl -p",
      ]
    )
  }
}

resource "null_resource" "systemd_override" {
  triggers = {
    user        = var.ssh_user
    port        = format("%d", var.ssh_port)
    private_key = var.private_key_openssh
    host        = aws_eip.ip.public_ip
  }
  depends_on = [null_resource.install_daemon]
  connection {
    type        = "ssh"
    user        = self.triggers.user
    port        = self.triggers.port
    private_key = self.triggers.private_key
    host        = self.triggers.host
  }
  provisioner "file" {
    destination = "/home/${var.ssh_user}/transmission-daemon-service-override.conf"
    content     = file(format("%s/%s", path.module, "templates/systemd-override.conf"))
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cp /home/${var.ssh_user}/transmission-daemon-service-override.conf /etc/systemd/system/transmission-daemon.service.d/override.conf",
      "sudo systemctl daemon-reload",
    ]
  }
}

resource "null_resource" "setup_config" {
  triggers = {
    user                  = var.ssh_user
    port                  = format("%d", var.ssh_port)
    private_key           = var.private_key_openssh
    host                  = aws_eip.ip.public_ip
    blocklist_url         = var.blocklist-url
    peer_port             = var.peer-port
    rpc_port              = var.rpc-port
    rpc_whitelist         = join(",", var.rpc-whitelist)
    rpc_username          = var.rpc-username
    rpc_password          = var.rpc-password
    rpc_enabled           = var.rpc-enabled
    download_dir          = var.download-dir
    incomplete_dir        = var.incomplete-dir
    peer-port-random-high = var.peer-port-random-high
    peer-port-random-low  = var.peer-port-random-low
  }
  depends_on = [null_resource.install_daemon]
  connection {
    type        = "ssh"
    user        = self.triggers.user
    port        = self.triggers.port
    private_key = self.triggers.private_key
    host        = self.triggers.host
  }
  provisioner "remote-exec" {
    inline = concat(
      [
        # Pause all
        "transmission-remote 127.0.0.1:${self.triggers.rpc_port} --auth=${self.triggers.rpc_username}:${self.triggers.rpc_password} --torrent all --stop || true",
        # Stop the daemon so we can configure it.
        "sudo systemctl stop transmission-daemon.service",
        # Create download dir
        "sudo mkdir -p ${self.triggers.download_dir}",
        "sudo chown -R debian-transmission:debian-transmission ${self.triggers.download_dir}",
        # Copy the settings file
        "sudo cp /etc/transmission-daemon/settings.json /tmp/settings.json",
        "sudo chmod 0666 /tmp/settings.json",
        <<EOT
        jq '."peer-port"=${self.triggers.peer_port}
          | ."peer-port-random-high"=${self.triggers.peer-port-random-high}
          | ."peer-port-random-low"=${self.triggers.peer-port-random-low}
          | ."download-dir"="${self.triggers.download_dir}"
          | ."rpc-authentication-required"=true
          | ."rpc-enabled"=${self.triggers.rpc_enabled}
          | ."rpc-port"=${self.triggers.rpc_port}
          | ."rpc-username"="${self.triggers.rpc_username}"
          | ."rpc-password"="${self.triggers.rpc_password}"
          | ."rpc-whitelist"="${self.triggers.rpc_whitelist}"
          ' /tmp/settings.json | sponge /tmp/settings.json
        EOT
      ],
      length(self.triggers.blocklist_url) > 0 ? [
        <<EOT
        jq '."blocklist-enabled"=true
          | ."blocklist-url"="${self.triggers.blocklist_url}"
        ' /tmp/settings.json | sponge /tmp/settings.json
        EOT
        ] : [
        "jq '\"blocklist-enabled\"=false' /tmp/settings.json | sponge /tmp/settings.json",
      ],
      length(self.triggers.incomplete_dir) > 0 ? [
        "sudo mkdir -p ${self.triggers.incomplete_dir}",
        "sudo chown -R debian-transmission:debian-transmission ${self.triggers.incomplete_dir}",
        <<EOT
        jq '."incomplete-dir-enabled"=true
          | ."incomplete-dir"="${self.triggers.incomplete_dir}"
        ' /tmp/settings.json | sponge /tmp/settings.json
        EOT
        ] : [
        "jq '.\"incomplete-dir-enabled\"=false' /tmp/settings.json | sponge /tmp/settings.json",
      ],
      [
        "sudo mv /tmp/settings.json /etc/transmission-daemon/settings.json",
        "sudo chown debian-transmission:debian-transmission /etc/transmission-daemon/settings.json",
        "sudo chmod 0600 /etc/transmission-daemon/settings.json",
        "sudo systemctl enable --now transmission-daemon.service",
        # Start paused torrents
        "transmission-remote 127.0.0.1:${self.triggers.rpc_port} --auth=${self.triggers.rpc_username}:${self.triggers.rpc_password} --torrent all --start || true",
      ]
    )
  }
}
