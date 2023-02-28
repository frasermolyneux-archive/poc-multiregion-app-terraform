resource "azurerm_cdn_frontdoor_firewall_policy" "fwp" {
  name = format("fwp%s%s", random_id.environment_id.hex, var.environment)

  resource_group_name = azurerm_resource_group.rg[var.locations[0]].name
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

resource "azurerm_cdn_frontdoor_security_policy" "example" {
  name = format("sp-%s-%s", random_id.environment_id.hex, var.environment)

  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.fwp.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.cd.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}
