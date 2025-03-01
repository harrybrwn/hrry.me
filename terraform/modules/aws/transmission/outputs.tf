output "public_ip" {
  value = aws_eip.ip.public_ip
}

output "ipv4" {
  value = aws_instance.main.public_ip
}

output "ipv6" {
  value = var.ipv6 ? element(aws_instance.main.ipv6_addresses, 0) : ""
}

output "stigrc" {
  value = <<EOT
set connect.host ${aws_eip.ip.public_ip}
set connect.port ${var.rpc-port}
set connect.user "${var.rpc-username}"
set connect.password "${var.rpc-password}"
EOT
}

output "auth" {
  value = "${var.rpc-username}:${var.rpc-password}"
}
