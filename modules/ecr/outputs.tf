output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}
output "nginx_repository_url" {
  value = aws_ecr_repository.nginx.repository_url
}
