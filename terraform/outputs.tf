output "web_app_names" {
  value = values(azurerm_linux_web_app.app)[*].name
}