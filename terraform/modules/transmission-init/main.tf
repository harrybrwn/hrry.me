locals {
  ephemeral_port_low  = 32768
  ephemeral_port_high = 60999
}

resource "null_resource" "install_daemon" {
  triggers = {
    user        = var.ssh_user
    port        = format("%d", var.ssh_port)
    host        = var.public_ip
    private_key = var.ssh_private_key
  }
  # depends_on = [aws_instance.main, aws_eip.ip]

  connection {
    type        = "ssh"
    user        = self.triggers.user
    port        = self.triggers.port
    host        = self.triggers.host
    private_key = self.triggers.private_key
  }
  provisioner "remote-exec" {
    inline = concat(
      [
        "sudo apt-get -y update",
        "sudo apt-get install -y transmission-daemon transmission-cli jq moreutils curl vim git software-properties-common unattended-upgrades",
        #"sudo hostnamectl set-hostname ${aws_instance.main.tags["Name"]}",
        "echo 'net.core.rmem_max = 4194304' | sudo tee -a /etc/sysctl.conf",
        "echo 'net.core.wmem_max = 1048576' | sudo tee -a /etc/sysctl.conf",
        # TODO uncomment this
        "echo 'net.ipv4.ip_local_port_range = ${local.ephemeral_port_low}\t${local.ephemeral_port_high}'",
        #"echo 'net.ipv4.ip_local_port_range = ${local.ephemeral_port_low}\t${local.ephemeral_port_high}' | sudo tee -a /etc/sysctl.conf",
        "sudo mkdir -p /etc/systemd/system/transmission-daemon.service.d",
      ],
      # if 'ipv6' is false then disable ipv6 on the machine
      #var.ipv6 == false ? [
      #  "echo 'net.ipv6.conf.all.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf",
      #  "echo 'net.ipv6.conf.default.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf",
      #  "echo 'net.ipv6.conf.lo.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf",
      #] : [],
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
    host        = var.public_ip
    private_key = var.ssh_private_key
  }
  depends_on = [null_resource.install_daemon]
  connection {
    type        = "ssh"
    user        = self.triggers.user
    port        = self.triggers.port
    host        = self.triggers.host
    private_key = self.triggers.private_key
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

locals {
  tmp_settings = "/tmp/settings.json"
  jq_cmd       = "jq '%s' ${local.tmp_settings} | sponge ${local.tmp_settings}"
}

resource "null_resource" "setup_config" {
  triggers = {
    user                   = var.ssh_user
    port                   = format("%d", var.ssh_port)
    host                   = var.public_ip
    private_key            = var.ssh_private_key
    blocklist_url          = var.blocklist-url
    peer_port              = var.peer-port
    rpc_port               = var.rpc-port
    rpc_whitelist          = join(",", var.rpc-whitelist)
    rpc_username           = var.rpc-username
    rpc_password           = var.rpc-password
    rpc_enabled            = var.rpc-enabled
    rpc-url                = var.rpc-url
    download_dir           = var.download-dir
    incomplete-dir         = var.incomplete-dir
    peer-limit-global      = var.peer-limit-global
    peer-limit-per-torrent = var.peer-limit-per-torrent
    peer-port-random-high  = var.peer-port-random-high
    peer-port-random-low   = var.peer-port-random-low
    speed-limit-up         = var.speed-limit-up
    speed-limit-down       = var.speed-limit-down
    ratio-limit            = var.ratio-limit
    cache-size-mb          = var.cache-size-mb
  }
  depends_on = [null_resource.install_daemon]
  connection {
    type        = "ssh"
    user        = self.triggers.user
    port        = self.triggers.port
    host        = self.triggers.host
    private_key = self.triggers.private_key
  }

  provisioner "remote-exec" {
    inline = concat(
      [
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
          | ."peer-limit-global"=${self.triggers.peer-limit-global}
          | ."peer-limit-per-torrent"=${self.triggers.peer-limit-per-torrent}
          | ."download-dir"="${self.triggers.download_dir}"
          | ."cache-size-mb"=${self.triggers.cache-size-mb}
          | ."rpc-authentication-required"=true
        %{if self.triggers.rpc_enabled}
          | ."rpc-enabled"=${self.triggers.rpc_enabled}
          | ."rpc-port"=${self.triggers.rpc_port}
          | ."rpc-username"="${self.triggers.rpc_username}"
          | ."rpc-password"="${self.triggers.rpc_password}"
          | ."rpc-whitelist"="${self.triggers.rpc_whitelist}"
          %{if length(self.triggers.rpc-url) > 0}
          | ."rpc-url"="${self.triggers.rpc-url}"
          %{endif}
        %{else}
          | ."rpc-enabled"=${self.triggers.rpc_enabled}
        %{endif}
        %{if length(self.triggers.blocklist_url) > 0}
          | ."blocklist-enabled"=true
          | ."blocklist-url"="${self.triggers.blocklist_url}"
        %{else}
          | ."blocklist-enabled"=false
        %{endif}
        %{if self.triggers.speed-limit-up > 0}
          | ."speed-limit-up-enabled"=true
          | ."speed-limit-up"=${self.triggers.speed-limit-up}
        %{endif}
        %{if self.triggers.speed-limit-down > 0}
          | ."speed-limit-down-enabled"=true
          | ."speed-limit-down"=${self.triggers.speed-limit-down}
        %{endif}
        %{if self.triggers.ratio-limit > 0}
          | ."ratio-limit-enabled"=true
          | ."ratio-limit"=${self.triggers.ratio-limit}
        %{endif}
        %{if length(self.triggers.incomplete-dir) > 0}
          | ."incomplete-dir-enabled"=true
          | ."incomplete-dir"="${self.triggers.incomplete-dir}"
        %{else}
          | ."incomplete-dir-enabled"=false
        %{endif}
          ' /tmp/settings.json | sponge /tmp/settings.json
        EOT
      ],
      length(self.triggers.incomplete-dir) > 0 ? [
        "sudo mkdir -p ${self.triggers.incomplete-dir}",
        "sudo chown -R debian-transmission:debian-transmission ${self.triggers.incomplete-dir}",
      ] : [],
      [
        "sudo mv /tmp/settings.json /etc/transmission-daemon/settings.json",
        "sudo chown debian-transmission:debian-transmission /etc/transmission-daemon/settings.json",
        "sudo chmod 0600 /etc/transmission-daemon/settings.json",
        "sleep 5",
        "sudo systemctl start transmission-daemon.service",
      ]
    )
  }
}
