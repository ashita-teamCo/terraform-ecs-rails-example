#
# staging で共通のリソースを定義する
#
terraform {
  backend "s3" {
    bucket = "example-project-staging-terraform-state"
    region = "ap-northeast-1"
    key = "shared.tfstate"
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

module "tags" {
  source = "../../modules/tags"

  suffix = module.variables.suffix
}

module "variables" {
  source = "../../modules/variables"
}

module "shared" {
  source = "../../modules/shared"

  for_each = module.variables.var.hosts

  host = each.value
  suffix = module.variables.suffix
}

module "ecr" {
  source = "../../modules/ecr"
}
