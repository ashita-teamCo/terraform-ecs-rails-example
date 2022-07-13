output "alb" {
  value = aws_lb.this
}
output "target_group_app" {
  value = aws_lb_target_group.app
}

output "target_group_basic_auth" {
  value = aws_lb_target_group.basic_auth
}

output "listener" {
  value = aws_lb_listener.https
}
