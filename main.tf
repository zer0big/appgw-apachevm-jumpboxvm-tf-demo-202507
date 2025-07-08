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
}

resource "azurerm_subnet" "web_subnet" {
  name                 = "web_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.web_subnet_prefix]
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "app_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.app_subnet_prefix]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "db_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.db_subnet_prefix]
}

resource "azurerm_subnet" "jumpbox_subnet" {
  name                 = "jumpbox_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# --- 공용 IP 주소들 ---
resource "azurerm_public_ip" "appgw_public_ip" {
  name                = "pip-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "jumpbox_public_ip" {
  name                = "pip-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# --- 네트워크 보안 그룹 (NSG) 및 연결 ---

# App Gateway 서브넷용 NSG
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

resource "azurerm_subnet_network_security_group_association" "appgw_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}

# Web 서브넷용 NSG
resource "azurerm_network_security_group" "web_nsg" {
  name                = "nsg-web-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowHttpInFromAppGateway"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = azurerm_subnet.appgw_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowSshInFromJumpbox"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.jumpbox_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.web_subnet.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

# App 서브넷용 NSG
resource "azurerm_network_security_group" "app_nsg" {
  name                = "nsg-app-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowTomcatInFromWebSubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080" # Tomcat 기본 포트
    source_address_prefix      = azurerm_subnet.web_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowSshInFromJumpbox"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.jumpbox_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

# DB 서브넷용 NSG
resource "azurerm_network_security_group" "db_nsg" {
  name                = "nsg-db-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowMysqlInFromAppSubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306" # MySQL/MariaDB 기본 포트
    source_address_prefix      = azurerm_subnet.app_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowSshInFromJumpbox"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.jumpbox_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "db_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

# Jumpbox 서브넷용 NSG
resource "azurerm_network_security_group" "jumpbox_nsg" {
  name                = "nsg-jumpbox-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSshInFromInternet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

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
    name                  = "backend-http-setting"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "http-probe-internal"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule-http"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool-apache"
    backend_http_settings_name = "backend-http-setting"
    priority                   = 100
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = var.appgw_waf_firewall_mode
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  probe {
    name                = "http-probe-internal"
    protocol            = "Http"
    host                = "127.0.0.1"
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }

  depends_on = [azurerm_network_security_group.appgw_nsg]
}

# --- 가용성 세트 ---
resource "azurerm_availability_set" "web_as" {
  name                         = "as-web-apache"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_availability_set" "app_as" {
  name                         = "as-app-tomcat"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_availability_set" "db_as" {
  name                         = "as-db-mysql"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# --- 네트워크 인터페이스 ---
resource "azurerm_network_interface" "web_ubuntu_nic" {
  name                = "nic-web-ubuntu-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "app_ubuntu_nic" {
  name                = "nic-app-ubuntu-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "db_ubuntu_nic" {
  name                = "nic-db-ubuntu-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

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

# --- Cloud-init 스크립트 ---
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
              echo "<h1>Hello from Apache on Web VM!</h1>" | sudo tee /var/www/html/index.html
              EOF
  }
}

data "cloudinit_config" "tomcat_cloud_init" {
  gzip          = true
  base64_encode = true
  part {
    filename     = "tomcat-install.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y openjdk-11-jre tomcat9
              sudo systemctl start tomcat9
              sudo systemctl enable tomcat9
              echo "<h1>Hello from Tomcat on App VM!</h1>" | sudo tee /var/lib/tomcat9/webapps/ROOT/index.html
              EOF
  }
}

# My-SQL 설치 시 주석 해제
/*
data "cloudinit_config" "mysql_cloud_init" {
  gzip          = true
  base64_encode = true
  part {
    filename     = "mysql-install.sh"
    content_type = "text/x-shellscript"
    # 중요: 이 스크립트는 데모용이며, root 암호가 'password'로 하드코딩되어 있음.
    # 운영 환경에서는 Azure Key Vault 같은 보안 서비스를 사용하여 암호를 관리해야 함.
    content = <<-EOF
              #!/bin/bash
              # 비-대화형 설치를 위해 DEBIAN_FRONTEND 설정
              export DEBIAN_FRONTEND=noninteractive
              # MySQL root 암호를 미리 설정
              sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password password'
              sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password password'
              # 패키지 업데이트 및 MySQL 서버 설치
              sudo apt-get update -y
              sudo apt-get install -y mysql-server
              # 외부(App Subnet)에서의 접속을 허용하도록 설정 변경
              sudo sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mysql/mysql.conf.d/mysqld.cnf
              # MySQL 서비스 재시작
              sudo systemctl restart mysql
              EOF
  }
}
*/

# Maria 설치 시 주석 해제
/*
data "cloudinit_config" "mariadb_cloud_init" {
  gzip          = true
  base64_encode = true
  part {
    filename     = "mariadb-install.sh"
    content_type = "text/x-shellscript"
    # 중요: 이 스크립트는 데모용이며, root 암호가 'password'로 하드코딩되어 있음.
    # 운영 환경에서는 Azure Key Vault 같은 보안 서비스를 사용하여 암호를 관리해야 함.
    content = <<-EOF
              #!/bin/bash
              # 비-대화형 설치를 위해 DEBIAN_FRONTEND 설정
              export DEBIAN_FRONTEND=noninteractive
              # MariaDB root 암호를 미리 설정
              sudo debconf-set-selections <<< 'mariadb-server mariadb-server/root_password password password'
              sudo debconf-set-selections <<< 'mariadb-server mariadb-server/root_password_again password password'
              # 패키지 업데이트 및 MariaDB 서버 설치
              sudo apt-get update -y
              sudo apt-get install -y mariadb-server
              # 외부(App Subnet)에서의 접속을 허용하도록 설정 변경
              # 파일 경로는 MariaDB 버전에 따라 다를 수 있음 (Ubuntu 22.04 기준)
              sudo sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mysql/mariadb.conf.d/50-server.cnf
              # MariaDB 서비스 재시작
              sudo systemctl restart mariadb
              EOF
  }
}
*/

# --- 가상 머신 (VMs) ---
resource "azurerm_linux_virtual_machine" "web_ubuntu_vm" {
  name                          = "web-ubuntu-vm-01"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  size                          = var.vm_size
  admin_username                = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids         = [azurerm_network_interface.web_ubuntu_nic.id]
  availability_set_id           = azurerm_availability_set.web_as.id

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

resource "azurerm_linux_virtual_machine" "app_ubuntu_vm" {
  name                          = "app-ubuntu-vm-01"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  size                          = var.vm_size
  admin_username                = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids         = [azurerm_network_interface.app_ubuntu_nic.id]
  availability_set_id           = azurerm_availability_set.app_as.id

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
  custom_data = data.cloudinit_config.tomcat_cloud_init.rendered
}

resource "azurerm_linux_virtual_machine" "db_ubuntu_vm" {
  name                          = "db-ubuntu-vm-01"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  size                          = var.vm_size
  admin_username                = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids         = [azurerm_network_interface.db_ubuntu_nic.id]
  availability_set_id           = azurerm_availability_set.db_as.id

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
#  custom_data = data.cloudinit_config.mysql_cloud_init.rendered
#  custom_data = data.cloudinit_config.mariadb_cloud_init.rendered
}

resource "azurerm_linux_virtual_machine" "jumpbox_vm" {
  name                          = "jumpbox-vm"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  size                          = var.vm_size
  admin_username                = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids         = [azurerm_network_interface.jumpbox_nic.id]

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
