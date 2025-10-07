module "afd_waf_policy" {
  source           = "Azure/avm-res-network-frontdoorwebapplicationfirewallpolicy/azurerm"
  version          = "~> 0.1.0"
  enable_telemetry = var.enable_telemetry

  name                = lower(join("", regexall("[a-zA-Z0-9]", replace(replace(local.naming_structure, "{resource_type}", "afd"), "{region}", "global"))))
  resource_group_name = local.resource_group_name
  tags                = var.tags

  mode = var.waf_mode
  # Required for Microsoft-managed WAF rules
  sku_name = local.front_door_sku_name

  managed_rules = [
    {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.1"
      action  = "Block"

      # overrides = [
      #   {
      #     rule_group_name = "UnknownBots"

      #     rules = [{
      #       rule_id = "Bot300500"
      #       action  = "Block"
      #       enabled = true
      #     }]
      #   }
      # ]
    },
    # Do not use a DefaultRuleSet
    # {
    #   type    = "Microsoft_DefaultRuleSet"
    #   version = "2.1"
    #   action  = "Log"
    # }
  ]

  request_body_check_enabled        = true
  custom_block_response_status_code = 403
  custom_block_response_body        = base64encode("Blocked by Azure WAF")

  custom_rules = [
    {
      name     = "GeoRestrict"
      action   = "Log"
      enabled  = true
      priority = 5
      # rate_limit_duration_in_minutes = 1
      # rate_limit_threshold = 100
      type = "MatchRule"

      match_conditions = [
        {
          match_variable     = "RemoteAddr"
          operator           = "GeoMatch"
          transforms         = []
          match_values       = ["RU", "KP", "IR"] # Russia, North Korea, Iran
          negation_condition = false
        }
      ]
    },
    {
      name                           = "BaseRateLimit"
      action                         = "Log"
      enabled                        = false
      priority                       = 10
      rate_limit_duration_in_minutes = 5
      rate_limit_threshold           = 100
      type                           = "RateLimitRule"

      match_conditions = [
        {
          match_variable = "RemoteAddr"
          operator       = "IPMatch"
          transforms     = []
          match_values = [
            "204.102.252.8",
            "137.164.16.255/32",
            "192.111.213.0/24",
          ]
          negation_condition = true
        }
      ]
    }
  ]
}

