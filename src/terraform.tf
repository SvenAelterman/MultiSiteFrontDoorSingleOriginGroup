terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.47.0"
    }
    # azapi = {
    #   source  = "Azure/azapi"
    #   version = "~> 2.7.0"
    # }
  }
}

provider "azurerm" {
  features {}
  subscription_id     = local.subscription_id
  storage_use_azuread = true
}

# provider "azapi" {
#   subscription_id = local.subscription_id
# }

data "azurerm_client_config" "current" {}
