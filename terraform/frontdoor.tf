resource "azurerm_resource_group" "fd" {
  name     = format("rg-fd-%s-%s-%s", random_id.environment_id.hex, var.environment, var.primary_location)
  location = var.primary_location

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = format("fd-%s-%s", random_id.environment_id.hex, var.environment)
  resource_group_name = azurerm_resource_group.fd.name
  sku_name            = "Premium_AzureFrontDoor"

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_firewall_policy" "fwp" {
  name = format("fwp%s%s", random_id.environment_id.hex, var.environment)

  resource_group_name = azurerm_resource_group.fd.name
  sku_name            = azurerm_cdn_frontdoor_profile.fd.sku_name

  enabled = true

  mode = "Detection"

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }
}

resource "azurerm_monitor_diagnostic_setting" "fd" {
  name = azurerm_log_analytics_workspace.law.name

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  target_resource_id = azurerm_cdn_frontdoor_profile.fd.id

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "FrontdoorAccessLog"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "FrontDoorHealthProbeLog"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"

    retention_policy {
      enabled = false
    }
  }
}
