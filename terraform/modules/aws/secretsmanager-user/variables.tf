variable "user_name" {
  description = "Name of the IAM user to create."
  type        = string
  default     = "secretsmanager-readonly"
}

variable "secret_arns" {
  type = list(string)
}

variable "aws_region" {
  type    = string
  default = null
}

variable "kms_key_arns" {
  type    = list(string)
  default = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
