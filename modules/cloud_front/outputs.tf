output "ssm_cdn_urls" {
  value = aws_ssm_parameter.cdn_url
}
output "ssm_cdn_buckets" {
  value = aws_ssm_parameter.s3_cdn_bucket_name
}

output "failover_distribution" {
  value = aws_cloudfront_distribution.failover
}
