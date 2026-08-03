output "state_bucket" {
  description = "S3 bucket to configure as TF_STATE_BUCKET in GitHub."
  value       = aws_s3_bucket.state.id
}

output "state_kms_key_arn" {
  description = "Customer-managed KMS key protecting OpenTofu state."
  value       = aws_kms_key.state.arn
}

output "github_plan_role_arn" {
  description = "Role ARN to configure as AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.github_plan.arn
}

output "github_apply_role_arn" {
  description = "Role ARN to configure as AWS_APPLY_ROLE_ARN."
  value       = aws_iam_role.github_apply.arn
}

output "state_bucket_retention_notice" {
  description = "The bootstrap state bucket is intentionally outside the EKS destroy path."
  value       = "Retained. Follow docs/runbooks/aws-destroy.md for the separate deletion procedure."
}
