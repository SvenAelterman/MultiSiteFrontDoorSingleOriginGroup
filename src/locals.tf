locals {
  subscription_id    = var.subscription_id
  instance_formatted = format("%02d", var.instance)

  naming_structure = replace(replace(replace(var.naming_convention, "{workload_name}", var.workload_name), "{environment}", var.environment), "{instance}", local.instance_formatted)
}

# Create a single map of all custom domains
locals {
  primary_domain_names   = [for site_key, site in var.sites : { domain_name = site.custom_domain_name, origin = site.origin }]
  alternate_domain_names = flatten([for site_key, site in var.sites : [for alt_domain in site.alternate_domain_names : { domain_name = alt_domain, origin = site.origin }]])
  all_domain_names       = concat(local.primary_domain_names, local.alternate_domain_names)

  all_domain_names_map = { for domain in local.all_domain_names : domain.domain_name => domain }
}

# Create a single list of all second-level domain names (www.example.com -> example.com, etc.)
# We need this list to reference the DNS zones when creating the Front Door custom domains
# locals {
#   all_second_level_domain_names = [for domain in local.all_domain_names : join(".", slice(split(".", domain), length(split(".", domain)) - 2, length(split(".", domain))))]
# }

locals {
  resource_group_name = length(var.existing_resource_group_name) > 0 ? var.existing_resource_group_name : module.resource_group_afd.name
}
