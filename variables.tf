# -----------------------------------------------------------------------------
# 일반 설정 (General Settings)
# -----------------------------------------------------------------------------
variable "resource_group_name" {
  description = "생성할 리소스 그룹의 이름입니다."
  type        = string
  default     = "rg-appgw-3tier-demo"
}

variable "location" {
  description = "리소스를 배포할 Azure 지역"
  type        = string
  default     = "Korea Central"
}

# -----------------------------------------------------------------------------
# 네트워크 설정 (Network Settings)
# -----------------------------------------------------------------------------
variable "web_subnet_prefix" {
  description = "Web Tier 서브넷의 주소 대역"
  type        = string
  default     = "10.0.3.0/24"
}

variable "app_subnet_prefix" {
  description = "App Tier (Tomcat) 서브넷의 주소 대역"
  type        = string
  default     = "10.0.4.0/24"
}

variable "db_subnet_prefix" {
  description = "DB Tier 서브넷의 주소 대역"
  type        = string
  default     = "10.0.5.0/24"
}

# -----------------------------------------------------------------------------
# Application Gateway 설정 (Application Gateway Settings)
# -----------------------------------------------------------------------------
variable "appgw_sku_capacity" {
  description = "Application Gateway WAF v2의 용량 단위(Capacity Unit)"
  type        = number
  default     = 2
}

variable "appgw_waf_firewall_mode" {
  description = "Application Gateway WAF의 방화벽 모드 (Prevention 또는 Detection)"
  type        = string
  default     = "Prevention"
}

# -----------------------------------------------------------------------------
# 가상 머신 설정 (Virtual Machine Settings)
# -----------------------------------------------------------------------------
variable "vm_size" {
  description = "배포할 가상 머신의 크기"
  type        = string
  default     = "Standard_B1s"
}

variable "vm_admin_username" {
  description = "가상 머신에 생성할 관리자 계정 이름"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "VM 접속에 사용할 SSH 공개 키 파일의 경로"
  type        = string
  # 중요: 이 경로는 terraform을 실행하는 사용자 PC의 실제 경로와 일치해야 함. 
  # 예: "~/.ssh/id_rsa.pub"
  default     = "~/.ssh/id_rsa.pub"
}
