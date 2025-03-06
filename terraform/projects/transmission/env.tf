resource "null_resource" "configure" {
  triggers = {
    private_key = module.key.private_key
    host        = module.transmission.public_ip
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    port        = 22
    private_key = self.triggers.private_key
    host        = self.triggers.host
  }
  depends_on = [module.transmission, module.key]
  provisioner "remote-exec" {
    script = <<EOT
{
  echo bind-key h select-pane -L
  echo bind-key k select-pane -U
  echo bind-key j select-pane -D
  echo bind-key l select-pane -R
} >> ~/.tmux.conf
echo "alias l='ls -hlA --group-directories-first --color=auto'"
EOT
  }
}

resource "null_resource" "configure_volume" {
  triggers = {
    host  = module.transmission.public_ip
    _name = "test"
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    port        = 22
    private_key = module.key.private_key
    host        = self.triggers.host
  }
  depends_on = [module.transmission, module.key]
  provisioner "remote-exec" {
    script = "auto-mount.sh"
  }
}
