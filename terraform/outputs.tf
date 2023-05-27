output "web_apps" {
  value = toset(zipmap(values(azurerm_linux_web_app.app)[*].name, values(azurerm_linux_web_app.app)[*].resource_group_name))
}

output "web_app_names" {
  value = values(azurerm_linux_web_app.app)[*].name
}
