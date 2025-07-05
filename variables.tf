# variables.tf
variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "rg-appgw-ubuntu-apache-demo"
}
variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
  default     = "koreacentral"
}
variable "vm_admin_username" {
  description = "Admin username for the VMs."
  type        = string
  default     = "azureuser"
}
variable "ssh_public_key_path" {
  description = "Path to the SSH public key file for VM authentication."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
variable "appgw_sku_capacity" {
  description = "Capacity for Application Gateway SKU (min 2 for WAF_v2)."
  type        = number
  default     = 2
}
variable "appgw_waf_firewall_mode" {
  description = "Firewall mode for WAF (Prevention or Detection)."
  type        = string
  default     = "Prevention"
  validation {
    condition     = contains(["Prevention", "Detection"], var.appgw_waf_firewall_mode)
    error_message = "The waf_firewall_mode must be 'Prevention' or 'Detection'."
  }
}
variable "vm_size" {
  description = "Size of the virtual machines."
  type        = string
  default     = "Standard_B1s"
}
