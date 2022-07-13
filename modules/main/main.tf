locals {
  hosts = keys(var.input.hosts)
}
module "network" {
  source = "../network"

  region = var.input.region
  name = var.input.name
  az_list = ["${var.input.region}a", "${var.input.region}c"]
  vpc_cidr = var.input.vpc_cidr
  public_subnet_cidr_list = var.input.public_subnet_cidr_list
  private_subnet_cidr_list = var.input.private_subnet_cidr_list
}

module "alb" {
  source = "../alb"

  for_each = toset(local.hosts)

  host = each.value
  name = var.input.name
  vpc_id = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  domain = var.input.domain
  acm_arn = var.input.acm_arn
  use_basic_auth = var.input.use_basic_auth
  sns_topic = module.sns_topic[each.key].sns_topic
  logs_bucket = module.s3[each.key].logs_bucket
  suffix = var.suffix
}

module "rds" {
  source = "../rds"

  for_each = toset(local.hosts)

  region = var.input.region
  name = var.input.name
  host = each.value
  vpc_id = module.network.vpc_id
  vpc_cidr_block = module.network.vpc_cidr_block
  old_vpc_cidr_block = var.input.old_vpc_cidr
  az_list = module.network.az_list
  private_subnet_ids = module.network.private_subnet_ids
  db_user = "app_user"
  instance_count = var.input.rds.instance_count
  instance_class = var.input.rds.instance_class
  max_connections = var.input.rds.max_connections
  sns_topic = module.sns_topic[each.key].sns_topic
  suffix = var.suffix
}

module "elasti_cache" {
  source = "../elasti_cache"

  for_each = toset(local.hosts)

  name = var.input.name
  host = each.key
  vpc_id = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  node_type = var.input.elasti_cache.node_type
  sns_topic = module.sns_topic[each.key].sns_topic
}

module "elasticseach" {
  source = "../elasticsearch"

  for_each = toset(local.hosts)

  name = var.input.name
  host = each.value
  vpc_id = module.network.vpc_id
  vpc_cidr_block = module.network.vpc_cidr_block
  private_subnet_ids = var.input.es.az_count == 1 ? [module.network.private_subnet_ids[0]] : module.network.private_subnet_ids
  instance_type = var.input.es.instance_type
  ebs_volume_size = var.input.es.ebs_volume_size
  sns_topic = module.sns_topic[each.value].sns_topic
  dedicated_master_enabled = var.input.es.dedicated_master_enabled
  dedicated_master_count = var.input.es.dedicated_master_count
  dedicated_master_type = var.input.es.dedicated_master_type
}

module "cloud_front" {
  source = "../cloud_front"

  for_each = toset(local.hosts)

  name = var.input.name
  domain = var.input.domain
  failover_certificate_arn = var.input.failover_acm_arn
  host = each.value
  suffix = var.suffix
  path = "assets"
}

module "ecs" {
  source = "../ecs"

  for_each = toset(local.hosts)

  name = var.input.name
  domain = var.input.domain
  host = each.value
  vpc_id = module.network.vpc_id
  vpc_cidr_block = module.network.vpc_cidr_block
  private_subnet_ids = var.input.es.az_count == 1 ? [module.network.private_subnet_ids[0]] : module.network.private_subnet_ids
  target_group_app = module.alb[each.value].target_group_app
  ssm_database_password = module.rds[each.value].ssm_database_password
  ssm_database_urls_writer = module.rds[each.value].ssm_database_urls_writer
  ssm_database_urls_reader = module.rds[each.value].ssm_database_urls_reader
  ssm_assets_urls = module.cloud_front[each.value].ssm_cdn_urls
  ssm_redis_urls = module.elasti_cache[each.value].ssm_redis_urls
  ssm_elasticsearch_urls = module.elasticseach[each.value].ssm_endpoints
  ssm_s3_help_buckets = module.s3[each.value].ssm_help_s3_buckets
  ssm_s3_buckets = module.s3[each.value].ssm_s3_buckets
  app_desired_count = var.input.ecs.app_desired_count
  batch_desired_count = var.input.ecs.batch_desired_count
  ecs_app_cpu = var.input.ecs.app_cpu
  ecs_batch_cpu = var.input.ecs.batch_cpu
  ecs_app_memory = var.input.ecs.app_memory
  ecs_batch_memory = var.input.ecs.batch_memory
  asc_batch_min_count = var.input.ecs.asc_batch_min_count
  asc_batch_max_count = var.input.ecs.asc_batch_max_count
  asc_batch_target = var.input.ecs.asc_batch_target
  asc_app_min_count = var.input.ecs.asc_app_min_count
  asc_app_max_count = var.input.ecs.asc_app_max_count
  asc_app_target = var.input.ecs.asc_app_target
  s3_access_policy_arn = module.s3[each.value].access_policy_arn
  suffix = var.suffix
  region = var.input.region
  sns_topic = module.sns_topic[each.value].sns_topic
  sns_topic_lambda = module.sns_topic_lambda[each.value].sns_topic
  cpu_alert_app_threshold = var.input.ecs.cpu_alert_app_threshold
  memory_alert_app_threshold = var.input.ecs.memory_alert_app_threshold
  cpu_alert_batch_threshold = var.input.ecs.cpu_alert_batch_threshold
  memory_alert_batch_threshold = var.input.ecs.memory_alert_batch_threshold
  rails_max_threads = var.input.ecs.rails_max_threads
  rails_database_pool_app = var.input.ecs.rails_database_pool_app
  rails_database_pool_batch = var.input.ecs.rails_database_pool_batch
}

module "s3" {
  source = "../s3"

  for_each = var.input.hosts

  name = var.input.name
  host = each.value
  host_name = each.key
  suffix = var.suffix
}
