data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_security_group" "this" {
  name        = "${var.name}-${var.host}-elasticsearch"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      var.vpc_cidr_block
    ]
  }
}

resource "aws_cloudwatch_log_resource_policy" "this" {
  policy_name = "example"

  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*"
    }
  ]
}
CONFIG
}

resource "aws_cloudwatch_log_group" "this" {
  name = "es_${var.name}_${var.host}"
}

resource "aws_elasticsearch_domain" "this" {
  domain_name           = "${var.name}-${var.host}"
  elasticsearch_version = "7.1"

  cluster_config {
    dedicated_master_enabled = var.dedicated_master_enabled
    dedicated_master_count = var.dedicated_master_count
    dedicated_master_type = var.dedicated_master_type
    instance_type = var.instance_type
    instance_count = length(var.private_subnet_ids)
    zone_awareness_enabled = length(var.private_subnet_ids) > 1
  }
  vpc_options {
    subnet_ids = var.private_subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.this.arn
    log_type = "INDEX_SLOW_LOGS"
  }
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.this.arn
    log_type = "SEARCH_SLOW_LOGS"
  }
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.this.arn
    log_type = "ES_APPLICATION_LOGS"
  }
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.this.arn
    log_type = "ES_APPLICATION_LOGS"
  }

  access_policies = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": "*",
            "Effect": "Allow",
            "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.name}-${var.host}/*"
        }
    ]
  })

  ebs_options {
    ebs_enabled = true
    volume_size = var.ebs_volume_size
  }

  tags = {
    Domain = var.name
  }
}

resource "aws_ssm_parameter" "endpoint" {
  name = "${var.name}_${var.host}_es_endpoint"
  type = "String"
  value = "https://${aws_elasticsearch_domain.this.endpoint}"
}


resource "aws_cloudwatch_metric_alarm" "cluster_status_red" {
  alarm_name                = "ES Threadpool Search Threads(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "ClusterStatus.red"
  namespace                 = "AWS/ES"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "1"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    DomainName = aws_elasticsearch_domain.this.domain_name
    ClientId = data.aws_caller_identity.current.account_id
  }
}

resource "aws_cloudwatch_metric_alarm" "free_space" {
  alarm_name                = "ES Free Storage Space(${var.name}_${var.host})"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "FreeStorageSpace"
  namespace                 = "AWS/ES"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "1000"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    DomainName = aws_elasticsearch_domain.this.domain_name
    ClientId = data.aws_caller_identity.current.account_id
  }
}

resource "aws_cloudwatch_metric_alarm" "index_write_block" {
  alarm_name                = "ES Index Writes Blocked(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "ClusterIndexWritesBlocked "
  namespace                 = "AWS/ES"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "1"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    DomainName = aws_elasticsearch_domain.this.domain_name
    ClientId = data.aws_caller_identity.current.account_id
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name                = "ES CPU(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUUtilization "
  namespace                 = "AWS/ES"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    DomainName = aws_elasticsearch_domain.this.domain_name
    ClientId = data.aws_caller_identity.current.account_id
  }
}

resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name                = "ES Memory(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "JVMMemoryPressure "
  namespace                 = "AWS/ES"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    DomainName = aws_elasticsearch_domain.this.domain_name
    ClientId = data.aws_caller_identity.current.account_id
  }
}
