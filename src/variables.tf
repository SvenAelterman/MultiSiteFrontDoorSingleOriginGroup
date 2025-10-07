variable "enable_telemetry" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "waf_mode" {
  type    = string
  default = "Prevention"

  validation {
    condition     = contains(["Prevention", "Detection"], var.waf_mode)
    error_message = "WAF mode must be either 'Prevention' or 'Detection'."
  }
}

variable "health_probe_path" {
  type        = string
  description = "The path for the health probe used by the CDN Front Door."
  default     = "/"
}

variable "dns_zone_resource_group_id" {
  type        = string
  description = "The resource group ID where the DNS zones are located."
  default     = ""
}

variable "existing_resource_group_name" {
  type        = string
  description = "If provided, use this existing resource group name instead of creating a new one."
  default     = ""
}

variable "origins" {
  type = map(object({
    origin_ips = map(string)
  }))
  description = "A map of origin groups and their IP addresses for the CDN Front Door."
  default     = {}
}

variable "sites" {
  type = map(object({
    custom_domain_name     = string
    alternate_domain_names = list(string)
    origin                 = string
  }))
  description = "A map of site names to their custom domain names for the CDN Front Door."
  default     = {}
}

variable "workload_name" {
  type        = string
  description = "The name of the workload, used for generating resource names."
}

variable "environment" {
  type        = string
  description = "The environment (e.g., dev, prod), used for generating resource names."
}

variable "instance" {
  type        = number
  description = "Instance number for the deployment, used for generating resource names."
  default     = 1

  validation {
    condition     = var.instance > 0
    error_message = "Instance must be a positive integer."
  }
}

variable "naming_convention" {
  type        = string
  description = "Naming convention template for resources, using placeholders like {workload_name}, {environment}, {instance}, {resource_type}, and {region}."
  default     = "{workload_name}-{environment}-{resource_type}-{region}-{instance}"
}

variable "subscription_id" {
  type        = string
  description = "The Azure Subscription ID where resources will be deployed."
}

variable "region" {
  type        = string
  description = "The primary Azure region for resource deployment."
  default     = ""
}
