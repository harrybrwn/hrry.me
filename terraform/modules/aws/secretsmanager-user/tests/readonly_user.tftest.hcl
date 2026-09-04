mock_provider "aws" {
  # The attachment resource validates ARN syntax at plan time, so the mocked
  # policy ARN must look like a real one.
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock"
    }
  }
}

variables {
  user_name   = "test-reader"
  secret_arns = ["arn:aws:secretsmanager:us-west-2:123456789012:secret:myapp/db-AbC123"]
}

run "creates_user_and_scoped_policy" {
  command = plan

  assert {
    condition     = aws_iam_user.this.name == "test-reader"
    error_message = "IAM user name should match var.user_name."
  }

  assert {
    condition = jsondecode(aws_iam_policy.read_secrets.policy).Statement[0].Action == [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    error_message = "Policy should allow only the read-only Secrets Manager actions."
  }

  assert {
    condition = jsondecode(aws_iam_policy.read_secrets.policy).Statement[0].Resource == [
      "arn:aws:secretsmanager:us-west-2:123456789012:secret:myapp/db-AbC123",
    ]
    error_message = "Policy should be scoped to exactly the configured secret ARNs."
  }

  assert {
    condition     = length(jsondecode(aws_iam_policy.read_secrets.policy).Statement) == 1
    error_message = "No KMS statement should be present when kms_key_arns is empty."
  }

  assert {
    condition     = aws_iam_user_policy_attachment.read_secrets.user == "test-reader"
    error_message = "Policy should be attached to the created user."
  }
}

run "adds_kms_decrypt_statement_when_keys_given" {
  command = plan

  variables {
    aws_region   = "eu-west-1"
    kms_key_arns = ["arn:aws:kms:us-west-2:123456789012:key/11111111-2222-3333-4444-555555555555"]
  }

  assert {
    condition     = jsondecode(aws_iam_policy.read_secrets.policy).Statement[1].Condition.StringEquals["kms:ViaService"] == "secretsmanager.eu-west-1.amazonaws.com"
    error_message = "kms:ViaService should use var.aws_region when it is set."
  }

  assert {
    condition     = length(data.aws_region.current) == 0
    error_message = "The aws_region data source should not run when var.aws_region is set."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.read_secrets.policy).Statement[1].Action == ["kms:Decrypt"]
    error_message = "A kms:Decrypt statement should be added when kms_key_arns is set."
  }

  assert {
    condition = jsondecode(aws_iam_policy.read_secrets.policy).Statement[1].Resource == [
      "arn:aws:kms:us-west-2:123456789012:key/11111111-2222-3333-4444-555555555555",
    ]
    error_message = "kms:Decrypt should be scoped to the configured key ARNs."
  }
}

run "rejects_non_secretsmanager_arns" {
  command = plan

  variables {
    secret_arns = ["arn:aws:s3:::not-a-secret"]
  }

  expect_failures = [var.secret_arns]
}

run "rejects_empty_secret_list" {
  command = plan

  variables {
    secret_arns = []
  }

  expect_failures = [var.secret_arns]
}
