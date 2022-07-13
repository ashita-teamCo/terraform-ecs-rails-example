output "ssm_database_password" {
  value = data.aws_ssm_parameter.password
}

output "ssm_database_urls_writer" {
  value = aws_ssm_parameter.database_url_writer
}
output "ssm_database_urls_reader" {
  value = aws_ssm_parameter.database_url_reader
}
