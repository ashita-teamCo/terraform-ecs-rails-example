terraform {
  backend "s3" {
    bucket = "example-project-staging-terraform-state"
    region = "ap-northeast-1"
    key = "staging.tfstate"
    profile = "example-project-staging"
    encrypt = true
  }
}

provider "aws" {
  region = module.variables.var.region
  profile = "example-project-staging"
  default_tags {
    tags = module.tags.default_tags
  }
}

locals {
  hosts = keys(module.variables.var.hosts)
}

module "variables" {
  source = "../../modules/variables"
}

module "tags" {
  source = "../../modules/tags"

  suffix = module.variables.suffix
}

module "main" {
  source = "../../modules/main"

  input = module.variables.var
  suffix = module.variables.suffix
}

module "basic_auth" {
  source = "../../modules/basic_auth"

  for_each = toset(keys(module.variables.var.hosts))

  region = module.variables.var.region
  host = each.value
  target_group_basic_auth = module.main.alb[each.value].target_group_basic_auth[0]
  suffix = module.variables.suffix
}

output "task_def" {
  value = module.main.ecs
}
