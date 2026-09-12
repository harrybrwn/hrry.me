data "aws_region" "current" {
  count = var.aws_region == null ? 1 : 0
}

locals {
  region = var.aws_region != null ? var.aws_region : data.aws_region.current[0].region

  read_secrets_statement = {
    Sid    = "ReadSecretValues"
    Effect = "Allow"
    Action = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    Resource = var.secret_arns
  }

  # Only needed when secrets are encrypted with a customer-managed key;
  # kms:ViaService limits decryption to calls made through Secrets Manager.
  decrypt_statement = {
    Sid      = "DecryptSecretsWithCmk"
    Effect   = "Allow"
    Action   = ["kms:Decrypt"]
    Resource = var.kms_key_arns
    Condition = {
      StringEquals = {
        "kms:ViaService" = "secretsmanager.${local.region}.amazonaws.com"
      }
    }
  }

  policy = {
    Version = "2012-10-17"
    Statement = concat(
      [local.read_secrets_statement],
      length(var.kms_key_arns) > 0 ? [local.decrypt_statement] : [],
    )
  }

  tags = merge({ Provisioner = "Terraform" }, var.tags)
}

resource "aws_iam_policy" "read_secrets" {
  name        = var.name
  description = "Read-only access to specific Secrets Manager secrets."
  policy      = jsonencode(local.policy)
  tags        = local.tags
}

resource "aws_iam_user_policy_attachment" "read_secrets" {
  count      = var.attatch_to_user == null ? 0 : 1
  user       = var.attatch_to_user
  policy_arn = aws_iam_policy.read_secrets.arn
}
