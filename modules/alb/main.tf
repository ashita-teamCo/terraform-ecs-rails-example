resource "aws_security_group" "this" {
  name = "${var.name}-${var.host}-alb"
  description = "${var.name}-alb"
  vpc_id = var.vpc_id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }

  tags = {
    Name = "${var.name}-alb"
  }
}

resource "aws_security_group_rule" "http" {
  security_group_id = aws_security_group.this.id

  type = "ingress"

  from_port = 80
  to_port = 80
  protocol = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "https" {
  security_group_id = aws_security_group.this.id

  type = "ingress"

  from_port = 443
  to_port = 443
  protocol = "tcp"

  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb" "this" {
  load_balancer_type = "application"
  name = "${var.name}-${var.host}"

  idle_timeout = 480
  security_groups = [aws_security_group.this.id]
  subnets = var.public_subnet_ids

  access_logs {
    bucket = var.logs_bucket.bucket
    prefix = "alb"
    enabled = true
  }
}

resource "aws_lb_target_group" "app" {
  name = "${var.name}-${var.host}"
  vpc_id = var.vpc_id

  port = 80
  protocol = "HTTP"
  target_type = "ip"
  deregistration_delay = 5
  health_check {
    interval =  30
    timeout = 15
    healthy_threshold = 2
    unhealthy_threshold = 10
    port = 80
    path = "/healthcheck"
  }
}

resource "aws_lb_listener" "http" {
  port = 80
  protocol = "HTTP"

  load_balancer_arn = aws_lb.this.arn

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  port = 443
  protocol = "HTTPS"

  load_balancer_arn = aws_lb.this.arn
  certificate_arn = var.acm_arn[0]
  default_action {
    type = "forward"
    target_group_arn = var.use_basic_auth == true ? aws_lb_target_group.basic_auth[0].arn : aws_lb_target_group.app.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}
resource "aws_lb_listener_certificate" "https" {
  for_each = toset(var.acm_arn)

  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = each.value
}
locals {
  valid_value = base64encode("") # FIXME: `ユーザ名:パスワード` 形式で文字列を組み立てる
}

resource "aws_lb_listener_rule" "healthcheck" {
  count = var.use_basic_auth ? 1 : 0

  listener_arn = aws_lb_listener.https.arn
  priority = 5

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = ["/healthcheck"]
    }
  }
}

resource "aws_lb_listener_rule" "basic_auth" {
  listener_arn = aws_lb_listener.https.arn
  priority = "100"

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    http_header {
      http_header_name = "Authorization"
      values           = ["Basic ${local.valid_value}"]
    }
  }
  lifecycle {
    ignore_changes = [action]
  }
}


resource "aws_lb_target_group" "basic_auth" {
  count = var.use_basic_auth == true ? 1 : 0

  name        = "basic-auth-${var.host}${var.suffix}"
  target_type = "lambda"
}

resource "aws_cloudwatch_metric_alarm" "request_count_app" {
  alarm_name                = "ALB Request Count Blue(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "RequestCount"
  namespace                 = "AWS/ApplicationELB"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "100"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup = aws_lb_target_group.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_count_app" {
  alarm_name                = "ALB UnHealthy Count Blue(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "UnHealthyHostCount"
  namespace                 = "AWS/ApplicationELB"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "1"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup = aws_lb_target_group.app.arn_suffix
  }
}
