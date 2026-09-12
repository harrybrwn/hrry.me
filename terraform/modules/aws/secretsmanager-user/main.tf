data "aws_region" "current" {
  count = var.aws_region == null ? 1 : 0
}

locals {
  region = var.aws_region != null ? var.aws_region : data.aws_region.current[0].region
  tags   = merge({ Provisioner = "Terraform" }, var.tags)
}

resource "aws_iam_user" "this" {
  name = var.user_name
  tags = local.tags
}

module "secretsmanager_policy" {
  source       = "../secretsmanager-read-policy"
  name         = "${var.user_name}-read-secrets"
  secret_arns  = var.secret_arns
  kms_key_arns = var.kms_key_arns
  tags         = local.tags
}

resource "aws_iam_user_policy_attachment" "read_secrets" {
  user       = aws_iam_user.this.name
  policy_arn = module.secretsmanager_policy.policy_arn
}
