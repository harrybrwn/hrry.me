variable "name" {
  description = "Name of the IAM policy to create."
  type        = string
}

variable "parameter_arns" {
  description = <<-EOT
    Parameter store ARNs the user may read. Full ARNs include a random
    six-character suffix; pass the exact ARN or a wildcard pattern such as
    "arn:aws:ssm:us-west-2:123456789012:paramater/myapp/*".
  EOT
  type        = list(string)

  validation {
    condition     = length(var.parameter_arns) > 0
    error_message = "parameter_arns must contain at least one ARN."
  }

  validation {
    condition = alltrue([
      for arn in var.parameter_arns :
      can(regex("^arn:aws[a-zA-Z-]*:ssm:[a-z0-9-]+:[0-9]{12}:parameter/.+$", arn))
    ])
    error_message = "Each entry must be an SSM parameter ARN (arn:<partition>:ssm:<region>:<account-id>:parameter/<name>)."
  }
}

variable "aws_region" {
  type    = string
  default = null
}

variable "kms_key_arns" {
  type    = list(string)
  default = []

  validation {
    condition = alltrue([
      for arn in var.kms_key_arns :
      can(regex("^arn:aws[a-zA-Z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/.+$", arn))
    ])
    error_message = "Each entry must be a KMS key ARN (arn:<partition>:kms:<region>:<account-id>:key/<key-id>)."
  }
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
