data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Using this instead of "aws_secretsmanager_secret" because it allows us to
# query using multiple tags. The Tagging API matches exact tag key/value pairs;
# the aws_secretsmanager_secrets data source cannot (its tag-key/tag-value
# filters match independently).
data "aws_resourcegroupstaggingapi_resources" "prd_k8s_secrets" {
  resource_type_filters = ["secretsmanager:secret"]
  tag_filter {
    key    = "env"
    values = [var.env]
  }
  tag_filter {
    key    = "k8s"
    values = ["true"]
  }
}

locals {
  username = "k8s-external-secrets"
}

module "secretsmanager_user" {
  source      = "../../modules/aws/secretsmanager-user"
  user_name   = local.username
  secret_arns = [for r in data.aws_resourcegroupstaggingapi_resources.prd_k8s_secrets.resource_tag_mapping_list : r.resource_arn]
  aws_region  = data.aws_region.current.region
}

module "ssm_reads_policy" {
  source     = "../../modules/aws/parameterstore-read-policy"
  aws_region = data.aws_region.current.region
  name       = local.username
  parameter_arns = [
    "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/*",
  ]
}

resource "aws_iam_user_policy_attachment" "read_ssm" {
  user       = module.secretsmanager_user.user_name
  policy_arn = module.ssm_reads_policy.policy_arn
}

resource "aws_iam_access_key" "user" {
  user = module.secretsmanager_user.user_name
}

resource "local_file" "creds_env" {
  filename = "./creds.env"
  content = join("\n", [
    "access_key_id=${aws_iam_access_key.user.id}",
    "access_secret_key=${aws_iam_access_key.user.secret}",
  ])
  file_permission = "0600"
}
