
variable "project_name" {
  type    = string
  default = "aws-transmission-daemon"
}

/* Transmission Settings */

variable "blocklist-url" {
  type    = string
  default = ""
}

variable "download-dir" {
  type    = string
  default = "/var/lib/transmission-daemon/downloads"
}

variable "incomplete-dir" {
  type    = string
  default = ""
}

variable "rpc-enabled" {
  type    = bool
  default = true
}

variable "rpc-port" {
  type    = number
  default = 9091
}

variable "rpc-username" {
  type    = string
  default = "transission"
}

variable "rpc-password" {
  type        = string
  description = "password for transmission-daemon rpc"
}

variable "rpc-whitelist" {
  type    = list(string)
  default = ["127.0.0.1"]
}

variable "rpc-url" {
  type    = string
  default = ""
}

variable "peer-port" {
  type    = number
  default = 51413
}

variable "peer-port-random-low" {
  type    = number
  default = 49152
}

variable "peer-port-random-high" {
  type    = number
  default = 65535
}

variable "peer-limit-global" {
  type    = number
  default = 200
}

variable "peer-limit-per-torrent" {
  type    = number
  default = 50
}

variable "speed-limit-up" {
  type        = number
  description = "Upload speed limit in kB/sec. Disable with negative value."
  default     = -1
}

variable "speed-limit-down" {
  type        = number
  description = "Download speed limit in kB/sec. Disable with negative value."
  default     = -1
}

variable "ratio-limit" {
  type    = number
  default = -1
}

variable "cache-size-mb" {
  type    = number
  default = 4
}

/* SSH */

variable "ssh_port" {
  type    = number
  default = 22
}

variable "ssh_user" {
  type = string
}

variable "ssh_private_key" {
  type = string
}

/* AWS Networking */

variable "public_ip" {
  type        = string
  description = "EC2 instance's public IP address. Can be provided from an aws_eip."
}
