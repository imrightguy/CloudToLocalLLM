variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "cloudtolocalllm-rg"
}

variable "location" {
  description = "The Azure region to deploy to"
  type        = string
  default     = "East US"
}

variable "cluster_name" {
  description = "The name of the AKS cluster"
  type        = string
  default     = "cloudtolocalllm-aks"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "cloudtolocalllm"
}

variable "node_count" {
  description = "The initial number of nodes for the default node pool"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "The VM size for the default node pool"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "azure_client_id" {
  description = "The Client ID for the Azure Service Principal"
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "The Client Secret for the Azure Service Principal"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "The Tenant ID for the Azure Service Principal"
  type        = string
  sensitive   = true
}

variable "azure_subscription_id" {
  description = "The Subscription ID for the Azure Service Principal"
  type        = string
  sensitive   = true
}