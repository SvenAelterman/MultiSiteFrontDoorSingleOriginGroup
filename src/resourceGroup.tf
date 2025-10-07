# Create a resource group for the global resources (Azure Front Door)
module "resource_group_afd" {
  count = length(var.existing_resource_group_name) > 0 ? 0 : 1

  source           = "Azure/avm-res-resources-resourcegroup/azurerm"
  version          = "~> 0.2.1"
  enable_telemetry = var.enable_telemetry

  name     = replace(replace(local.naming_structure, "{resource_type}", "rg-afd"), "{region}", var.region)
  location = var.region # Use the first region for the region of the AFD resource group
  tags     = var.tags
}
