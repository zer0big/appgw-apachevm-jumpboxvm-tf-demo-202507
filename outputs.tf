# outputs.tf
output "application_gateway_public_ip" {
  description = "The public IP address of the Application Gateway."
  value       = azurerm_public_ip.appgw_public_ip.ip_address
}
output "jumpbox_public_ip" {
  description = "The public IP address of the Jumpbox VM."
  value       = azurerm_public_ip.jumpbox_public_ip.ip_address
}
output "web_ubuntu_vm_private_ip" {
  description = "The private IP address of the Web Ubuntu VM (Apache)."
  value       = azurerm_network_interface.web_ubuntu_nic.private_ip_address
}
output "app_ubuntu_vm_private_ip" {
  description = "The private IP address of the App Ubuntu VM."
  value       = azurerm_network_interface.app_ubuntu_nic.private_ip_address
}
