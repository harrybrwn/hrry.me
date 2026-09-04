output "user_name" {
  description = "Name of the IAM user."
  value       = aws_iam_user.this.name
}

output "user_arn" {
  description = "ARN of the IAM user."
  value       = aws_iam_user.this.arn
}

output "policy_arn" {
  description = "ARN of the read-only secrets policy."
  value       = aws_iam_policy.read_secrets.arn
}
