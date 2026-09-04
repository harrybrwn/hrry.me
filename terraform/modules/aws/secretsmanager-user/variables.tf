variable "user_name" {
  description = "Name of the IAM user to create."
  type        = string
  default     = "secretsmanager-readonly"
}

variable "secret_arns" {
  description = <<-EOT
    Secrets Manager secret ARNs the user may read. Full ARNs include a random
    six-character suffix; pass the exact ARN or a wildcard pattern such as
    "arn:aws:secretsmanager:us-west-2:123456789012:secret:myapp/*".
  EOT
  type        = list(string)

  validation {
    condition     = length(var.secret_arns) > 0
    error_message = "secret_arns must contain at least one secret ARN."
  }

  validation {
    condition = alltrue([
      for arn in var.secret_arns :
      can(regex("^arn:aws[a-zA-Z-]*:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", arn))
    ])
    error_message = "Each entry must be a Secrets Manager secret ARN (arn:<partition>:secretsmanager:<region>:<account-id>:secret:<name>)."
  }
}

variable "aws_region" {
  type    = string
  default = null
}

variable "kms_key_arns" {
  description = <<-EOT
    ARNs of customer-managed KMS keys used to encrypt the secrets. Required for
    secrets not encrypted with the AWS-managed key aws/secretsmanager; grants
    kms:Decrypt restricted to use via Secrets Manager.
  EOT
  type        = list(string)
  default     = []

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
