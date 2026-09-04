variable "env" {
  type    = string
  default = "prd"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
