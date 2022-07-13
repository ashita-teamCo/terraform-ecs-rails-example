resource "aws_elasticache_subnet_group" "this" {
  name = "redis-subnet-${var.name}-${var.host}"
  subnet_ids = var.private_subnet_ids
}

module "elasticache_for_redis_cluster_sg" {
  source  = "terraform-aws-modules/security-group/aws"

  name   = "${var.name}-redis-sg"
  vpc_id = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      description = "ElastiCache for Redis Cluster inbound ports"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_elasticache_parameter_group" "this" {
  name = var.name
  family = "redis5.0"

  parameter {
    name = "cluster-enabled"
    value = "no"
  }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-${var.host}"
  replication_group_description = "${var.name}-${var.host} Redis Replication group"

  engine = "redis"
  engine_version = "5.0.6"
  node_type = var.node_type
  port = "6379"

  parameter_group_name = aws_elasticache_parameter_group.this.name

  subnet_group_name = aws_elasticache_subnet_group.this.name
  security_group_ids = [module.elasticache_for_redis_cluster_sg.security_group_id]
  number_cache_clusters = 1
}

resource "aws_ssm_parameter" "redis_url" {
  name = "${var.name}_redis_url_${var.host}"
  type = "String"
  value = "redis://${aws_elasticache_replication_group.this.primary_endpoint_address}:6379/0"
}


resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name                = "Redis CPU(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ElastiCache"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    CacheClusterId = "${aws_elasticache_replication_group.this.replication_group_id}-001"
    CacheNodeId = "0001"
  }
}
