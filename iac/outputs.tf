output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "get_kubeconfig_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.this.name}"
}

output "appgw_public_fqdn" {
  value = azurerm_public_ip.appgw.fqdn
}

output "llm_endpoint_hint" {
  value = "${var.enable_tls ? "HTTPS" : "HTTP"} endpoint: ${var.enable_tls ? "https" : "http"}://${var.appgw_dns_label}.${var.location}.cloudapp.azure.com/v1/chat/completions"
}
