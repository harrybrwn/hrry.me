data "aws_region" "current" {}

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


module "user" {
  source      = "../../modules/aws/secretsmanager-user"
  user_name   = "k8s-external-secrets"
  secret_arns = [for r in data.aws_resourcegroupstaggingapi_resources.prd_k8s_secrets.resource_tag_mapping_list : r.resource_arn]
  aws_region  = data.aws_region.current.region
}

resource "aws_iam_access_key" "user" {
  user = module.user.user_name
}

resource "local_file" "creds_env" {
  filename = "./creds.env"
  content = join("\n", [
    "access_key_id=${aws_iam_access_key.user.id}",
    "access_secret_key=${aws_iam_access_key.user.secret}",
  ])
  file_permission = "0600"
}
