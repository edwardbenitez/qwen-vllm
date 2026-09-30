variable "location" {
  description = "Azure region to deploy resources into."
  type        = string
  default     = "eastus"
}

variable "subscription_id" {
  description = "Target Azure subscription ID. Passed explicitly to the azurerm provider (e.g. via TF_VAR_subscription_id) so it skips auto-detecting the subscription via Azure CLI."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "rg-vllm-aks"
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "aks-vllm"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. Leave null to use the latest default supported by the provider."
  type        = string
  default     = null
}

variable "node_count" {
  description = "Number of nodes in the default (CPU-only) node pool."
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "VM size for the AKS node pool. CPU-only, medium size."
  type        = string
  default     = "Standard_D2s_v6" # 4 vCPU / 16 GiB RAM, CPU-only
}

variable "user_node_count" {
  description = "Number of nodes in the user node pool for application workloads."
  type        = number
  default     = 1
}

variable "user_node_vm_size" {
  description = "VM size for the user node pool."
  type        = string
  default     = "Standard_D2s_v6"
}

variable "dockerhub_username" {
  description = "Docker Hub account or organization name hosting the image."
  type        = string
  default     = "mightydevs"
}

variable "image_name" {
  description = "Docker Hub repository name hosting the vLLM server image."
  type        = string
  default     = "qwen-vllm-cpu"
}

variable "image_tag" {
  description = "Published Docker Hub image tag hosting the vLLM server."
  type        = string
  default     = "1.0.1-amd64"
}

variable "container_port" {
  description = "Port the vLLM OpenAI-compatible server listens on inside the container."
  type        = number
  default     = 8000
}

variable "replica_count" {
  description = "Number of pod replicas serving the LLM endpoint."
  type        = number
  default     = 1
}

variable "vnet_address_space" {
  description = "Address space for the VNet hosting AKS and the Application Gateway."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "Address prefix for the AKS node subnet."
  type        = list(string)
  default     = ["10.10.1.0/24"]
}

variable "appgw_subnet_prefix" {
  description = "Address prefix for the dedicated Application Gateway subnet."
  type        = list(string)
  default     = ["10.10.2.0/24"]
}

variable "appgw_sku_name" {
  description = "Application Gateway SKU name. Standard_v2 is the cheapest tier that supports AGIC and TLS."
  type        = string
  default     = "Standard_v2"
}

variable "appgw_sku_tier" {
  description = "Application Gateway SKU tier."
  type        = string
  default     = "Standard_v2"
}

variable "appgw_capacity" {
  description = "Fixed Application Gateway instance count (no autoscaling) to minimize cost."
  type        = number
  default     = 1
}

variable "appgw_dns_label" {
  description = "Globally unique DNS label for the Application Gateway's public IP, e.g. '<label>.<region>.cloudapp.azure.com'."
  type        = string
  default     = "vllm-qwen-demo"
}

variable "enable_tls" {
  description = "Enable HTTPS with a Let's Encrypt certificate. Requires a real contact email."
  type        = bool
  default     = false
}

variable "letsencrypt_email" {
  description = "Real contact email for the Let's Encrypt ACME account when enable_tls is true."
  type        = string
  default     = ""
}
