variable "project_name" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "ipv6" {
  type    = bool
  default = false
}

variable "rpc-port" {
  type    = number
  default = 9091
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
