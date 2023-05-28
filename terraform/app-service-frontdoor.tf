resource "azurerm_cdn_frontdoor_endpoint" "app" {
  name                     = format("ep-app-%s-%s", random_id.environment_id.hex, var.environment)
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "app" {
  name                     = format("og-app-%s-%s", random_id.environment_id.hex, var.environment)
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

resource "azurerm_cdn_frontdoor_origin" "app" {
  for_each = toset(var.locations)

  name                          = format("o-app-%s-%s-%s", random_id.environment_id.hex, var.environment, each.value)
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.app.id

  enabled = true

  certificate_name_check_enabled = true

  host_name          = azurerm_linux_web_app.app[each.value].default_hostname
  http_port          = 80
  https_port         = 443
  origin_host_header = azurerm_linux_web_app.app[each.value].default_hostname
  priority           = 1
  weight             = 50
}

resource "azurerm_dns_cname_record" "app" {
  name = format("%s-%s", random_id.environment_id.hex, var.environment)

  zone_name           = data.azurerm_dns_zone.dns.name
  resource_group_name = data.azurerm_dns_zone.dns.resource_group_name

  ttl    = 300
  record = azurerm_cdn_frontdoor_endpoint.app.host_name
  tags   = var.tags
}

resource "azurerm_cdn_frontdoor_custom_domain" "app" {
  name = format("cd-app-%s-%s", random_id.environment_id.hex, var.environment)

  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  dns_zone_id              = data.azurerm_dns_zone.dns.id

  host_name = format("%s.%s", azurerm_dns_cname_record.app.name, data.azurerm_dns_zone.dns.name)

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "app" {
  name = format("sp-app-%s-%s", random_id.environment_id.hex, var.environment)

  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.fwp.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.app.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}

resource "azurerm_dns_txt_record" "app" {
  name = format("_dnsauth.%s", azurerm_dns_cname_record.app.name)

  zone_name           = data.azurerm_dns_zone.dns.name
  resource_group_name = data.azurerm_dns_zone.dns.resource_group_name

  ttl  = 300
  tags = var.tags

  record {
    value = azurerm_cdn_frontdoor_custom_domain.app.validation_token
  }
}

resource "azurerm_cdn_frontdoor_route" "app" {
  name = format("r-app-%s-%s", random_id.environment_id.hex, var.environment)

  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.app.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.app.id

  cdn_frontdoor_origin_ids = values(azurerm_cdn_frontdoor_origin.app)[*].id

  enabled = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.app.id]
  link_to_default_domain          = false
}
