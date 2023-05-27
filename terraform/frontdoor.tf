resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = format("fd-%s-%s", random_id.environment_id.hex, var.environment)
  resource_group_name = azurerm_resource_group.rg[var.locations[0]].name
  sku_name            = "Premium_AzureFrontDoor"

  tags = var.tags
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

resource "azurerm_cdn_frontdoor_endpoint" "ep" {
  name                     = format("ep-%s-%s", random_id.environment_id.hex, var.environment)
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "og" {
  name                     = format("og-%s-%s", random_id.environment_id.hex, var.environment)
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    interval_in_seconds = 60
    path                = "/"
    protocol            = "Https"
    request_type        = "GET"
  }

  session_affinity_enabled = false
}

resource "azurerm_cdn_frontdoor_origin" "o" {
  for_each = toset(var.locations)

  name                          = format("o-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id

  enabled = true

  certificate_name_check_enabled = true

  host_name          = azurerm_linux_web_app.app[each.value].default_hostname
  http_port          = 80
  https_port         = 443
  origin_host_header = azurerm_linux_web_app.app[each.value].default_hostname
  priority           = 1
  weight             = 50
}

resource "azurerm_dns_cname_record" "cn" {
  name = format("%s-%s", random_id.environment_id.hex, var.environment)

  zone_name           = data.azurerm_dns_zone.dns.name
  resource_group_name = data.azurerm_dns_zone.dns.resource_group_name

  ttl    = 300
  record = azurerm_cdn_frontdoor_endpoint.ep.host_name
  tags   = var.tags
}

resource "azurerm_cdn_frontdoor_custom_domain" "cd" {
  name = format("cd-%s-%s", random_id.environment_id.hex, var.environment)

  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  dns_zone_id              = data.azurerm_dns_zone.dns.id

  host_name = format("%s.%s", azurerm_dns_cname_record.cn.name, data.azurerm_dns_zone.dns.name)

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_dns_txt_record" "auth" {
  name = format("_dnsauth.%s", azurerm_dns_cname_record.cn.name)

  zone_name           = data.azurerm_dns_zone.dns.name
  resource_group_name = data.azurerm_dns_zone.dns.resource_group_name

  ttl  = 300
  tags = var.tags

  record {
    value = azurerm_cdn_frontdoor_custom_domain.cd.validation_token
  }
}

resource "azurerm_cdn_frontdoor_route" "r" {
  name = format("r-%s-%s", random_id.environment_id.hex, var.environment)

  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.ep.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id

  cdn_frontdoor_origin_ids = [azurerm_cdn_frontdoor_origin.o["uksouth"].id, azurerm_cdn_frontdoor_origin.o["ukwest"].id]

  enabled = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.cd.id]
  link_to_default_domain          = false
}
