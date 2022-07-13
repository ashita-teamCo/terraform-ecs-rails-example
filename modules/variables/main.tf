locals {
  main_var = yamldecode(file("../variables.yml"))
  workspace_yaml_string = fileexists("../variables.${terraform.workspace}.yml") ? file("../variables.${terraform.workspace}.yml") : "{}"
  workspace_var = yamldecode(local.workspace_yaml_string)
  var = (terraform.workspace == "default" ? local.main_var : merge(local.main_var, local.workspace_var))
  suffix = terraform.workspace == "default" ? "" : "-${terraform.workspace}"
}
