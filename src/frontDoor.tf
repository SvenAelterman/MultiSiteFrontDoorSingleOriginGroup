locals {
  front_door_sku_name = "Premium_AzureFrontDoor"
}

module "afd_waf_policy" {
  source           = "Azure/avm-res-network-frontdoorwebapplicationfirewallpolicy/azurerm"
  version          = "~> 0.1.0"
  enable_telemetry = var.enable_telemetry

  name                = lower(join("", regexall("[a-zA-Z0-9]", replace(replace(local.naming_structure, "{resource_type}", "afd"), "{region}", "global"))))
  resource_group_name = module.resource_group_afd.name
  tags                = var.tags

  mode = var.waf_mode
  # Required for Microsoft-managed WAF rules
  sku_name = local.front_door_sku_name

  request_body_check_enabled        = true
  custom_block_response_status_code = 403
  custom_block_response_body        = base64encode("Blocked by Azure WAF")

  custom_rules = []
}

resource "azurerm_cdn_frontdoor_profile" "afd" {
  name                = replace(replace(local.naming_structure, "{resource_type}", "afd"), "{region}", "global")
  resource_group_name = module.resource_group_afd.name
  sku_name            = local.front_door_sku_name

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "fde" {
  name                     = replace(replace(local.naming_structure, "{resource_type}", "fde-${var.workload_name}"), "{region}", "global")
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id

  tags = var.tags
}

# Create as many origin groups as there are sites to serve
# While all origin groups will have the same origin IPs, they all need different host headers
# Host headers cannot be dynamically rewritten
resource "azurerm_cdn_frontdoor_origin_group" "origin_group" {
  for_each = var.sites

  name                     = "origin-${each.key}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 2
  }

  # TODO: Not working as expected
  session_affinity_enabled = false

  health_probe {
    interval_in_seconds = 240
    path                = var.health_probe_path
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

# Create a flattened map of all origins by combining the sites and origin_ips variables
locals {
  all_origins_list = flatten([for site_key, site in var.sites : [
    for origin_key, origin_ip in var.origin_ips : [{

      name        = "${site_key}-${origin_key}"
      site_key    = site_key
      domain_name = site.custom_domain_name
      origin_key  = origin_key
      origin_ip   = origin_ip
    }]
  ]])

  all_origins_map = { for origin in local.all_origins_list : origin.name => origin }
}

# We need as many origins as there are sites * origin IPs
resource "azurerm_cdn_frontdoor_origin" "origin" {
  for_each = local.all_origins_map

  name                          = "origin-${each.key}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group[each.value.site_key].id
  enabled                       = true

  certificate_name_check_enabled = false # Requirement because host_name is an IP and there is no IP TLS

  host_name          = each.value.origin_ip
  origin_host_header = each.value.domain_name
  priority           = 1
  weight             = 1
}

# Create a single map of all custom domains
locals {
  primary_domain_names   = [for site in var.sites : site.custom_domain_name]
  alternate_domain_names = flatten([for site in var.sites : site.alternate_domain_names])
  all_domain_names       = concat(local.primary_domain_names, local.alternate_domain_names)

  all_domain_names_map = { for domain in local.all_domain_names : domain => domain }
}

# Create custom domains for all primary and secondary domains
resource "azurerm_cdn_frontdoor_custom_domain" "domain" {
  for_each = local.all_domain_names_map

  name                     = "domain--${replace(each.value, ".", "-")}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  host_name                = each.value

  # TODO: Add dns_zone_id

  tls {
    certificate_type = "ManagedCertificate"
  }
}

# resource "azurerm_cdn_frontdoor_security_policy" "afd_security_policy" {
#   name                     = "sec-${var.workload_name}"
#   cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id

#   security_policies {
#     firewall {
#       cdn_frontdoor_firewall_policy_id = module.afd_waf_policy.resource_id

#       # TODO: Associate the custom domains
#       # association {
#       #   domain {
#       #     cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.domain.id
#       #   }
#       #   patterns_to_match = ["/*"]
#       # }
#     }
#   }
# }

resource "azurerm_cdn_frontdoor_rule_set" "rule_set" {
  name                     = join("", regexall("[a-z0-9]", lower("${var.workload_name}Redirects")))
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
}

# Create a permanent redirect rule for each site redirecting each alternative domain to the primary domain
resource "azurerm_cdn_frontdoor_rule" "redirect" {
  for_each = var.sites

  # Using regular expressions, remove any non-alphanumeric characters from the site key to form a valid resource name
  # regexall returns a list, so we need to join it back into a single string without separators
  name                      = "Redirect${join("", regexall("[a-z0-9]", lower(each.key)))}"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.rule_set.id

  behavior_on_match = "Stop"
  order             = 100 + index(keys(var.sites), each.key) + 1

  actions {
    url_redirect_action {
      redirect_type        = "Moved"
      redirect_protocol    = "Https"
      destination_hostname = each.value.custom_domain_name
    }
  }

  conditions {
    host_name_condition {
      operator         = "Contains"
      match_values     = each.value.alternate_domain_names
      negate_condition = false
      transforms       = []
    }
  }
}

resource "azurerm_cdn_frontdoor_route" "route" {
  for_each = var.sites

  name                          = "route-${each.key}"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fde.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.origin_group[each.key].id
  enabled                       = true

  # Associate the origins that belong to this origin group
  cdn_frontdoor_origin_ids = [for origin in local.all_origins_list : azurerm_cdn_frontdoor_origin.origin[origin.name].id if origin.site_key == each.key]

  cdn_frontdoor_rule_set_ids = [
    azurerm_cdn_frontdoor_rule_set.rule_set.id
  ]

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match = [
    "/*"
  ]
  supported_protocols = [
    "Http",
    "Https"
  ]

  # Associate all custom domains (the primary and all alternates) that belong to this site
  cdn_frontdoor_custom_domain_ids = concat([for domain in var.sites[each.key].alternate_domain_names : azurerm_cdn_frontdoor_custom_domain.domain[domain].id], [azurerm_cdn_frontdoor_custom_domain.domain[each.value.custom_domain_name].id])

  link_to_default_domain = false
}
