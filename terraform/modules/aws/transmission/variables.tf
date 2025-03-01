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

variable "rpc-enabled" {
  type    = bool
  default = true
}

variable "peer-port" {
  type    = number
  default = 51413
}

variable "peer-port-random-high" {
  type    = number
  default = 65535
}

variable "peer-port-random-low" {
  type    = number
  default = 49152
}

/* AWS Networking */

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "ipv6" {
  type        = bool
  default     = false
  description = "Set to 'true' to enable ipv6 networking."
}

/* EC2 Instance Settings */

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "vpc_security_group_ids" {
  type    = list(string)
  default = []
}

variable "instance_volume_size" {
  type        = number
  description = "EC2 instance root volume size in Gib"
  default     = 32 # 0 disables the volume
}

variable "instance_volumes" {
  type = list(object({
    volume_id   = number
    device_name = string
    mount_path  = optional(string)
  }))
  description = "A list used to generate volume attachments."
  default     = []
}

/* SSH */

variable "ssh_port" {
  type    = number
  default = 22
}

variable "ssh_user" {
  type = string
}

variable "ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "public_key_openssh" {
  type = string
}

variable "private_key_openssh" {
  type = string
}
