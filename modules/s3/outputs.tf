output "ssm_s3_buckets" {
  value = aws_ssm_parameter.s3_bucket_name
}

output "ssm_help_s3_buckets" {
  value = aws_ssm_parameter.help_s3_bucket_name
}

output "access_policy_arn" {
  value = aws_iam_policy.this.arn
}

output "logs_bucket" {
  value = aws_s3_bucket.logs
}
