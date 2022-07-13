locals {
  rds_name = "${var.name}-mysql"
}
resource "aws_security_group" "this" {
  name = local.rds_name
  vpc_id = var.vpc_id

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.rds_name
  }
}

resource "aws_security_group_rule" "mysql" {
  security_group_id = aws_security_group.this.id

  type = "ingress"

  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  cidr_blocks = [var.vpc_cidr_block]
}

resource "aws_security_group_rule" "mysql_from_old_vpc" {
  # old_vpc_cider_block に値が設定されている場合のみ作成する
  count = var.old_vpc_cidr_block == "" ? 0 : 1

  security_group_id = aws_security_group.this.id

  type = "ingress"

  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  cidr_blocks = [var.old_vpc_cidr_block]
}

resource "aws_iam_role" "monitoring" {
  name = "${var.name}_rds_monitoring${var.suffix}"
  path = "/"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "monitoring.rds.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = "${aws_iam_role.monitoring.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_subnet_group" "this" {
  name = local.rds_name
  description = local.rds_name
  subnet_ids = var.private_subnet_ids
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${local.rds_name}-${var.host}"

  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  availability_zones = [ "${var.region}a", "${var.region}c"]

  enabled_cloudwatch_logs_exports = [
    "audit",
    "error",
    "general",
    "slowquery",
  ]

  engine = "aurora-mysql"
  port = 3306
  skip_final_snapshot = true
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  master_username = var.db_user
  master_password = data.aws_ssm_parameter.password.value
  backup_retention_period = 30
  lifecycle {
    ignore_changes = [
      master_password,
      availability_zones
    ]
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count
  identifier = "${local.rds_name}-${var.host}-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id

  engine = "aurora-mysql"
  instance_class = var.instance_class

  performance_insights_enabled = false
  apply_immediately = true

  monitoring_role_arn = aws_iam_role.monitoring.arn
  monitoring_interval = 60
}

resource "aws_rds_cluster_parameter_group" "this" {
  name = local.rds_name
  family  = "aurora-mysql5.7"

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "max_connections"
    value = var.max_connections
  }
  parameter {
    name  = "general_log"
    value = "0"
  }
  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  parameter {
    name  = "long_query_time"
    value = "1"
  }
}

data "aws_ssm_parameter" "password" {
  name = "database_password_${var.name}_${var.host}"
}


resource "aws_ssm_parameter" "database_url_writer" {
  name = "${var.name}_${var.host}_database_url_writer"
  type = "String"
  value = "mysql2://${var.db_user}@${aws_rds_cluster.this.endpoint}/example_production"
}

resource "aws_ssm_parameter" "database_url_reader" {
  name = "${var.name}_${var.host}_database_url_reader"
  type = "String"
  value = "mysql2://${var.db_user}@${aws_rds_cluster.this.reader_endpoint}/example_production"
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name                = "RDS CPU(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/RDS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    Role = "WRITER"
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }
}
resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name                = "RDS Memory(${var.name}_${var.host})"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "FreeableMemory"
  namespace                 = "AWS/RDS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "100"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "write_latency" {
  alarm_name                = "RDS Write Latency(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "WriteLatency"
  namespace                 = "AWS/RDS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "0.01"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "read_latency" {
  alarm_name                = "RDS Read Latency(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "ReadLatency"
  namespace                 = "AWS/RDS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "0.5"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "free_storage" {
  alarm_name                = "RDS Free Storage(${var.name}_${var.host})"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "FreeLocalStorage"
  namespace                 = "AWS/RDS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "100000000"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }
}
