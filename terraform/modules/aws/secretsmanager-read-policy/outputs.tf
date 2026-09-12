output "policy_arn" {
  description = "ARN of the read-only secrets policy."
  value       = aws_iam_policy.read_secrets.arn
}
