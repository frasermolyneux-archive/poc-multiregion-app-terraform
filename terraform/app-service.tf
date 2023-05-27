resource "azurerm_linux_web_app" "app" {
  for_each = toset(var.locations)

  name = format("app-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)

  resource_group_name = azurerm_resource_group.rg[each.value].name
  location            = azurerm_resource_group.rg[each.value].location

  service_plan_id = azurerm_service_plan.sp[each.value].id

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"             = azurerm_application_insights.ai[each.value].instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING"      = azurerm_application_insights.ai[each.value].connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "location"                                   = each.value
  }

  https_only = true

  site_config {
    ftps_state = "FtpsOnly"

    application_stack {
      dotnet_version = "7.0"
    }

    ip_restriction {
      action      = "Allow"
      service_tag = "AzureFrontDoor.Backend"

      headers {
        x_azure_fdid = [azurerm_cdn_frontdoor_profile.fd.resource_guid]
      }

      name     = "RestrictToFrontDoor"
      priority = 1000
    }
  }
}

resource "azapi_update_resource" "app" {
  for_each = toset(var.locations)

  type        = "Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01"
  name = format("%s/scm", azurerm_linux_web_app.app[each.value].name)

  body = jsonencode({
    properties = {
      allow = true
    }
  })

  depends_on = [
    azurerm_linux_web_app.app,
  ]
}

resource "azurerm_monitor_diagnostic_setting" "app" {
  for_each = toset(var.locations)

  name = azurerm_log_analytics_workspace.law.name

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  target_resource_id = azurerm_linux_web_app.app[each.value].id

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AppServiceAntivirusScanAuditLogs"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AppServiceHTTPLogs"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AppServiceConsoleLogs"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AppServiceAppLogs"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AppServiceFileAuditLogs"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AppServiceAuditLogs"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AppServiceIPSecAuditLogs"

    retention_policy {
      enabled = false
    }
  }

  enabled_log {
    category = "AppServicePlatformLogs"

    retention_policy {
      enabled = false
    }
  }
}