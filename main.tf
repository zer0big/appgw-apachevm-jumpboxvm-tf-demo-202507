# Azure Provider 설정
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}
provider "azurerm" {
  features {}
}
# --- 리소스 그룹 ---
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
# --- 가상 네트워크 (VNet) ---
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-appgw-ubuntu"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}
# --- 서브넷 (각각 독립적인 리소스) ---
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  /*
  delegation {
    name = "appgwdelegation"
    service_delegation {
      name    = "Microsoft.Network/applicationGateways"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
  */
}
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_subnet" "jumpbox_subnet" {
  name                 = "jumpbox_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}
# --- Application Gateway용 공용 IP ---
resource "azurerm_public_ip" "appgw_public_ip" {
  name                = "pip-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# --- Jumpbox VM용 공용 IP ---
resource "azurerm_public_ip" "jumpbox_public_ip" {
  name                = "pip-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# --- Application Gateway 서브넷용 네트워크 보안 그룹 (NSG) ---
resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "nsg-appgw-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    # destination_address_prefix = azurerm_subnet.appgw_subnet.address_prefixes[0]
    destination_address_prefix = "*" 
  }
  security_rule {
    name                       = "AllowPublicHTTP"
    priority                   = 200 
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowPublicHTTPS"
    priority                   = 210 
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}
# AppGW 서브넷에 NSG 연결
resource "azurerm_subnet_network_security_group_association" "appgw_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}
# --- VM 서브넷용 네트워크 보안 그룹 (NSG) ---
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "nsg-vm-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "AllowSSH_From_Jumpbox"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.jumpbox_subnet.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.vm_subnet.address_prefixes[0]
  }
  security_rule {
    name                       = "AllowHTTP_From_AppGW"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = azurerm_subnet.appgw_subnet.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.vm_subnet.address_prefixes[0]
  }
}
# VM 서브넷에 NSG 연결
resource "azurerm_subnet_network_security_group_association" "vm_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}
# --- Jumpbox 서브넷용 네트워크 보안 그룹 (NSG) ---
resource "azurerm_network_security_group" "jumpbox_nsg" {
  name                = "nsg-jumpbox-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = azurerm_subnet.jumpbox_subnet.address_prefixes[0]
  }
}
# Jumpbox 서브넷에 NSG 연결
resource "azurerm_subnet_network_security_group_association" "jumpbox_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.jumpbox_subnet.id
  network_security_group_id = azurerm_network_security_group.jumpbox_nsg.id
}
# --- Application Gateway (WAF) ---
resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-apache-waf"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = var.appgw_sku_capacity
  }
  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }
  frontend_port {
    name = "http-port"
    port = 80
  }
  frontend_ip_configuration {
    name                 = "appgw-frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw_public_ip.id
  }
  backend_address_pool {
    name         = "backend-pool-apache"
    ip_addresses = [azurerm_network_interface.web_ubuntu_nic.private_ip_address]
  }
  backend_http_settings {
    name                          = "backend-http-setting"
    cookie_based_affinity         = "Disabled"
    port                          = 80
    protocol                      = "Http"
    request_timeout               = 60
    probe_name                    = "http-probe-internal"
  }
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }
  request_routing_rule {
    name                        = "routing-rule-http"
    rule_type                   = "Basic"
    http_listener_name          = "http-listener"
    backend_address_pool_name   = "backend-pool-apache"
    backend_http_settings_name  = "backend-http-setting"
    priority                    = 100
  }

  # WAF 구성
  waf_configuration {
    enabled          = true
    firewall_mode    = var.appgw_waf_firewall_mode
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  probe {
    name                                = "http-probe-internal" 
    protocol                            = "Http"
    host                                = "127.0.0.1"
    path                                = "/"
    interval                            = 30
    timeout                             = 30
    unhealthy_threshold                 = 3
    # pick_host_name_from_backend_http_settings = true
  }
}
# --- 웹 VM용 가용성 세트 ---
resource "azurerm_availability_set" "web_as" {
  name                = "as-web-apache"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  platform_fault_domain_count   = 2
  platform_update_domain_count  = 2
  managed                     = true
}
# --- 웹 Ubuntu VM (Apache)용 네트워크 인터페이스 ---
resource "azurerm_network_interface" "web_ubuntu_nic" {
  name                = "nic-web-ubuntu-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
# --- Apache 설치용 Cloud-init 스크립트 ---
data "cloudinit_config" "apache_cloud_init" {
  gzip          = true
  base64_encode = true
  part {
    filename     = "apache-install.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "<h1>Hello from Apache on Web Ubuntu VM!</h1>" | sudo tee /var/www/html/index.html
              echo "Current hostname: $(hostname)" | sudo tee -a /var/www/html/index.html
              EOF
  }
}
# --- 웹 Ubuntu VM (Apache 백엔드) ---
resource "azurerm_linux_virtual_machine" "web_ubuntu_vm" {
  name                            = "web-ubuntu-vm-01"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.web_ubuntu_nic.id]
  availability_set_id             = azurerm_availability_set.web_as.id
  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  custom_data = data.cloudinit_config.apache_cloud_init.rendered
}
# --- 앱 Ubuntu VM용 네트워크 인터페이스 ---
resource "azurerm_network_interface" "app_ubuntu_nic" {
  name                = "nic-app-ubuntu-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
# --- 앱 Ubuntu VM ---
resource "azurerm_linux_virtual_machine" "app_ubuntu_vm" {
  name                            = "app-ubuntu-vm-01"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app_ubuntu_nic.id]
  availability_set_id             = azurerm_availability_set.web_as.id
  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
# --- Jumpbox VM용 네트워크 인터페이스 ---
resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "nic-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.jumpbox_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox_public_ip.id
  }
}
# --- Jumpbox VM ---
resource "azurerm_linux_virtual_machine" "jumpbox_vm" {
  name                            = "jumpbox-vm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.jumpbox_nic.id]
  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
