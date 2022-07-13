data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_security_group" "ecs" {
  name = "${var.name}_ecs"
  description = "${var.name} ecs"

  vpc_id = var.vpc_id

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-ecs"
  }
}

resource "aws_security_group_rule" "ecs" {
  security_group_id = aws_security_group.ecs.id

  type = "ingress"

  from_port = 80
  to_port = 80
  protocol = "tcp"

  cidr_blocks = [var.vpc_cidr_block]
}

resource "aws_iam_role" "ecs_events" {
  name = "${var.name}-EcsEventsRole${var.suffix}"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "events.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
  })
}
resource "aws_iam_role_policy" "ecs_events" {
  role = aws_iam_role.ecs_events.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ecs:RunTask",
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role" "task_execution" {
  name = "${var.name}-TaskExecution${var.suffix}"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs" {
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecs:DescribeClusters",
          "ecs:DescribeTaskDefinition",
          "ecs:RunTask",
          "events:DeleteRule",
          "events:ListRules",
          "events:ListTargetsByRule",
          "events:PutRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "iam:GetRole",
          "iam:PassRole"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_exec" {
  name = "ecs_exec_${var.name}_${var.host}${var.suffix}"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.ecs_exec.arn
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.task_execution.name
  policy_arn = var.s3_access_policy_arn
}

resource "aws_cloudwatch_log_group" "app" {
  name = "${var.name}_${var.host}_app"
}

resource "aws_cloudwatch_log_group" "batch" {
  name = "${var.name}_${var.host}_batch"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}_${var.host}"
  capacity_providers = ["FARGATE"]

  setting {
    name = "containerInsights"
    value = "enabled"
  }
}

data "aws_ecr_repository" "app" {
  name = "example_project"
}

data "aws_ecr_repository" "nginx" {
  name = "nginx"
}

locals {
  container_def_params = {
    log_group_app = aws_cloudwatch_log_group.app.name
    log_group_batch = aws_cloudwatch_log_group.batch.name
    ssm_database_password = var.ssm_database_password.name
    ssm_database_url_writer = var.ssm_database_urls_writer.name
    ssm_database_url_reader = var.ssm_database_urls_reader.name
    ssm_assets_url = var.ssm_assets_urls.name
    ssm_redis_url = var.ssm_redis_urls.name
    ssm_elasticsearch_url = var.ssm_elasticsearch_urls.name
    ssm_s3_bucket_name = var.ssm_s3_buckets.name
    ssm_s3_help_bucket_name = var.ssm_s3_help_buckets.name
    ssm_secret_key_base = aws_ssm_parameter.secret_key_base.name
    ssm_devise_secret_key = aws_ssm_parameter.devise_secret_key.name
    ssm_mail_to_system_admin = aws_ssm_parameter.mail_to_system_admin.name
    ssm_smtp_username = aws_ssm_parameter.smtp_username.name
    ssm_smtp_password = aws_ssm_parameter.smtp_password.name
    ssm_smtp_domain = aws_ssm_parameter.smtp_domain.name
    ssm_smtp_address = aws_ssm_parameter.smtp_address.name
    base_domain = var.domain
    rails_max_threads = var.rails_max_threads
    rails_database_pool_app = var.rails_database_pool_app
    rails_database_pool_batch = var.rails_database_pool_batch
    region = var.region
    nginx_image = data.aws_ecr_repository.nginx.repository_url
    image =  data.aws_ecr_repository.app.repository_url
  }

  task_def_params_app =  {
    execution_role_arn = aws_iam_role.task_execution.arn
    cpu = var.ecs_app_cpu
    memory = var.ecs_app_memory
    family = "${var.name}_${var.host}_app"
  }

  task_def_params_batch =  {
    execution_role_arn = aws_iam_role.task_execution.arn
    cpu = var.ecs_batch_cpu
    memory = var.ecs_batch_memory
    family = "${var.name}_${var.host}_batch"
  }
}
data "template_file" "container_definitions_app" {
  template = file("${path.module}/templates/container_definitions_app.json")
  vars = local.container_def_params
}

data "template_file" "container_definitions_batch" {
  template = file("${path.module}/templates/container_definitions_batch.json")
  vars = local.container_def_params
}

data "template_file" "container_definitions_output_app" {
  template = file("${path.module}/templates/container_definitions_app.json")
  vars = merge(local.container_def_params, {image: "<IMAGE_NAME>"})
}

data "template_file" "container_definitions_output_batch" {
  template = file("${path.module}/templates/container_definitions_batch.json")
  vars = merge(local.container_def_params, {image: "<IMAGE_NAME>"})
}

data "template_file" "task_definitions_app" {
  template = file("${path.module}/templates/task_definition.json")
  vars = merge(local.task_def_params_app, {container_definitions: data.template_file.container_definitions_output_app.rendered})
}

data "template_file" "task_definitions_batch" {
  template = file("${path.module}/templates/task_definition.json")
  vars = merge(local.task_def_params_batch, {container_definitions: data.template_file.container_definitions_output_batch.rendered})
}

resource "aws_ecs_task_definition" "batch" {
  family = "${var.name}_${var.host}_batch"
  container_definitions = data.template_file.container_definitions_batch.rendered

  task_role_arn = aws_iam_role.task_execution.arn
  execution_role_arn = aws_iam_role.task_execution.arn
  cpu                      = var.ecs_batch_cpu
  memory                   = var.ecs_batch_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

resource "aws_ecs_task_definition" "app" {
  family = "${var.name}_${var.host}_app"
  container_definitions = data.template_file.container_definitions_app.rendered
  task_role_arn = aws_iam_role.task_execution.arn
  execution_role_arn = aws_iam_role.task_execution.arn
  cpu                      = var.ecs_app_cpu
  memory                   = var.ecs_app_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  volume {
    name = "tmp"
  }
}

resource "aws_ecs_service" "app" {
  name = "app"
  cluster = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type = "FARGATE"
  enable_execute_command = true
  desired_count = var.app_desired_count
  propagate_tags = "SERVICE"
  load_balancer {
    target_group_arn = var.target_group_app.arn
    container_name = "nginx"
    container_port = 80
  }

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition
    ]
  }
}
resource "aws_ecs_service" "batch" {
  name = "batch"
  cluster = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.batch.arn
  launch_type = "FARGATE"
  enable_execute_command = true
  desired_count = var.batch_desired_count
  propagate_tags = "SERVICE"

  deployment_circuit_breaker {
    enable = true
    rollback = true
  }

  network_configuration {
    subnets = var.private_subnet_ids
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition,
      load_balancer,
    ]
  }
}
resource "aws_ssm_parameter" "secret_key_base" {
  name = "secret_key_base_${var.name}_${var.host}"
  type = "SecureString"
  value = "dummy"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "devise_secret_key" {
  name = "devise_secret_key_${var.name}_${var.host}"
  type = "SecureString"
  value = "dummy"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "mail_to_system_admin" {
  name = "mail_to_system_admin_${var.name}_${var.host}"
  type = "String"
  value = "dummy"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "smtp_username" {
  name = "smtp_username_${var.name}_${var.host}"
  type = "String"
  value = "dummy"

  lifecycle {
    ignore_changes = [value]
  }
}
resource "aws_ssm_parameter" "smtp_password" {
  name = "smtp_password_${var.name}_${var.host}"
  type = "SecureString"
  value = "dummy"

  lifecycle {
    ignore_changes = [value]
  }
}
resource "aws_ssm_parameter" "smtp_domain" {
  name = "smtp_domain_${var.name}_${var.host}"
  type = "String"
  value = "dummy"

  lifecycle {
    ignore_changes = [value]
  }
}
resource "aws_ssm_parameter" "smtp_address" {
  name = "smtp_address_${var.name}_${var.host}"
  type = "String"
  value = "dummy"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_cloudwatch_metric_alarm" "app_cpu" {
  alarm_name                = "ECS APP CPU(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = var.cpu_alert_app_threshold
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "batch_cpu" {
  alarm_name                = "ECS Batch CPU(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = var.cpu_alert_batch_threshold
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.batch.name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_memory" {
  alarm_name                = "ECS APP Memory(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "MemoryUtilization"
  namespace                 = "AWS/ECS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = var.memory_alert_app_threshold
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_redeploy" {
  alarm_name                = "ECS APP ReDeploy(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "MemoryUtilization"
  namespace                 = "AWS/ECS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = var.memory_alert_app_threshold - 5
  alarm_actions             = [var.sns_topic_lambda.arn]

  dimensions  = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "batch_memory" {
  alarm_name                = "ECS Batch Memory(${var.name}_${var.host})"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "MemoryUtilization"
  namespace                 = "AWS/ECS"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = var.memory_alert_batch_threshold
  alarm_actions             = [var.sns_topic.arn]

  dimensions  = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.batch.name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_task_count" {
  alarm_name                = "ECS APP Task Count(${var.name}_${var.host})"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "MemoryUtilization"
  namespace                 = "AWS/ECS"
  period                    = "60"
  statistic                 = "SampleCount"
  threshold                 = "1"
  alarm_actions             = [var.sns_topic.arn]
  treat_missing_data        = "breaching"

  dimensions  = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.app.name
  }
}

resource "aws_cloudwatch_metric_alarm" "batch_task_count" {
  alarm_name                = "ECS Batch Task Count(${var.name}_${var.host})"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "MemoryUtilization"
  namespace                 = "AWS/ECS"
  period                    = "300"
  statistic                 = "SampleCount"
  datapoints_to_alarm       = "2"
  threshold                 = "1"
  alarm_actions             = [var.sns_topic.arn]
  treat_missing_data        = "breaching"

  dimensions  = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.batch.name
  }
}

resource "aws_cloudwatch_event_rule" "ecs_events" {
  name = "${var.name}_${var.host}_ecs_state_change"
  event_pattern = jsonencode({
    "source": ["aws.ecs"],
    "detail-type": ["ECS Service Action", "ECS Task State Change", "ECS Container Instance State Change"],
    "detail": {
      "clusterArn": [aws_ecs_cluster.this.arn],
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_events" {
  rule = aws_cloudwatch_event_rule.ecs_events.name
  arn = aws_cloudwatch_log_group.ecs_events.arn
}

resource "aws_cloudwatch_log_group" "ecs_events" {
  name = "/aws/events/${var.name}_${var.host}_ecs_state_change"
  retention_in_days = 90
}

resource "aws_cloudwatch_log_resource_policy" "ecs_events" {
  policy_name = "${var.name}_${var.host}_event_logging_policy"
  policy_document = jsonencode({
    "Statement": [
      {
        "Action": [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect": "Allow",
        "Principal": {
          "Service": ["events.amazonaws.com", "delivery.logs.amazonaws.com"]
        },
        "Resource": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/events/*:*",
        "Sid": "TrustEventsToStoreLogEvent"
      }
    ],
    "Version": "2012-10-17"
  })
}
