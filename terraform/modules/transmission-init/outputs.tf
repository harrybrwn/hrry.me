output "stigrc" {
  value = <<EOT
set connect.host ${var.public_ip}
set connect.port ${var.rpc-port}
set connect.user "${var.rpc-username}"
set connect.password "${var.rpc-password}"
EOT
}

output "auth" {
  value = "${var.rpc-username}:${var.rpc-password}"
}
