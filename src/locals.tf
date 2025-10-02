locals {
  subscription_id    = var.subscription_id
  instance_formatted = format("%02d", var.instance)

  naming_structure = replace(replace(replace(var.naming_convention, "{workload_name}", var.workload_name), "{environment}", var.environment), "{instance}", local.instance_formatted)
}
