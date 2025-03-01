provider "aws" {
  profile = "terraform"
  region  = var.region
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "k3d-hrry-dev"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
    #config_context = "hrry-prd"
    config_context = "k3d-hrry-dev"
  }
}

locals {
  tags = {
    Name        = "homelab-vault"
    Provisioner = "Terraform"
  }
  user = "vault"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_user" "vault" {
  name = local.user
  tags = local.tags
}

resource "aws_iam_access_key" "access" {
  user   = resource.aws_iam_user.vault.name
  status = "Active"
}

resource "aws_kms_key" "unseal" {
  description         = "KMS Key for Vault auto-unseal."
  key_usage           = "ENCRYPT_DECRYPT"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.key.json
  tags                = local.tags
}

data "aws_iam_policy_document" "key" {
  statement {
    sid = "KeyAdministratoion"
    actions = [
      "kms:CancelKeyDeletion",
      "kms:Create*",
      "kms:Delete*",
      "kms:Describe*",
      "kms:Disable*",
      "kms:Enable*",
      "kms:Get*",
      "kms:ImportKeyMaterial",
      "kms:List*",
      "kms:Put*",
      "kms:ReplicateKey",
      "kms:Revoke*",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:Update*",
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }
  }

  statement {
    sid = "KeyUsage"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [resource.aws_iam_user.vault.arn]
    }
  }

  statement {
    sid    = "RootAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalType"
      values   = ["Account"]
    }
  }
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
}

resource "kubernetes_secret" "aws_iam" {
  metadata {
    name      = "vault-iam"
    namespace = resource.kubernetes_namespace.vault.id
  }
  type = "Opaque"
  data = {
    AWS_REGION               = var.region
    VAULT_AWSKMS_SEAL_KEY_ID = resource.aws_kms_key.unseal.id
    AWS_ACCESS_KEY_ID        = resource.aws_iam_access_key.access.id
    AWS_SECRET_ACCESS_KEY    = resource.aws_iam_access_key.access.secret
  }
}

resource "helm_release" "vault" {
  count         = 1
  name          = "vault"
  chart         = "vault"
  version       = "0.29.1"
  repository    = "https://helm.releases.hashicorp.com"
  namespace     = resource.kubernetes_namespace.vault.id
  wait_for_jobs = true
  set = [
    {
      name  = "server.dev.enabled"
      value = "false"
    },
    {
      name  = "server.standalone.enabled"
      value = "false"
    },
    {
      name  = "server.ha.enabled"
      value = "true"
    },
    {
      name  = "ui.enabled"
      value = "true"
    },
    # In prd set the storageClass to "nfs"
    #{
    #  name  = "server.dataStorage.storageClass"
    #  value = "nfs"
    #},
  ]
  values = [
    file("./vault-values.yml")
  ]
}
