resource "azurerm_public_ip" "appgw" {
  name                = "${var.cluster_name}-appgw-pip"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.appgw_dns_label
}

# BYO Application Gateway so AGIC can be attached via ingress_application_gateway.gateway_id.
resource "azurerm_application_gateway" "this" {
  name                = "${var.cluster_name}-appgw"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  sku {
    name     = var.appgw_sku_name # Standard_v2: cheapest SKU that supports AGIC + TLS
    tier     = var.appgw_sku_tier
    capacity = var.appgw_capacity # fixed capacity (no autoscaling) to minimize cost
  }

  # Azure now rejects the legacy default TLS policy; pin to a current predefined policy (TLS 1.2+).
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Placeholder backend/listener/rule required at creation time; AGIC rewrites these once installed.
  backend_address_pool {
    name = "placeholder-pool"
  }

  backend_http_settings {
    name                  = "placeholder-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "placeholder-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "placeholder-rule"
    rule_type                  = "Basic"
    http_listener_name         = "placeholder-listener"
    backend_address_pool_name  = "placeholder-pool"
    backend_http_settings_name = "placeholder-settings"
    priority                   = 100
  }

  # AGIC actively manages listeners/rules/certs at runtime; don't fight it on subsequent applies.
  lifecycle {
    ignore_changes = [
      frontend_port,
      frontend_ip_configuration,
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      probe,
      url_path_map,
      ssl_certificate,
      tags,
    ]
  }
}

# Grant the AKS-managed AGIC identity permission to reconfigure the BYO gateway.
# principal_type is set explicitly to skip the provider's Microsoft Graph lookup of the principal.
resource "azurerm_role_assignment" "agic_appgw_contributor" {
  scope                = azurerm_application_gateway.this.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "agic_appgw_subnet_network_contributor" {
  scope                = azurerm_subnet.appgw.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "agic_rg_reader" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  principal_type       = "ServicePrincipal"
}
