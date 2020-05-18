variable "resource_group_name" {
  description = "Name of the resource group."
}

variable "location" {
  description = "Location of the cluster."
}

variable "aks_service_subscription_id" {
  description = "Subscription ID."
}
variable "aks_service_principal_app_id" {
  description = "Application ID/Client ID  of the service principal. Used by AKS to manage AKS related resources on Azure like vms, subnets."
}
variable "aks_service_principal_tenant_id" {
  description = "Tenant ID/Client ID  of the service principal. Used by AKS to manage AKS related resources on Azure like vms, subnets."
}

variable "aks_service_principal_client_secret" {
  description = "Secret of the service principal. Used by AKS to manage Azure."
}

variable "aks_service_principal_object_id" {
  description = "Object ID of the service principal."
}

variable "virtual_network_name" {
  description = "Virtual network name"
  default     = "aksVirtualNetwork"
}

variable "virtual_network_address_prefix" {
  description = "Containers DNS server IP address."
  default     = "15.0.0.0/8"
}

variable "aks_subnet_name" {
  description = "AKS Subnet Name."
  default     = "kubesubnet"
}

variable "aks_subnet_address_prefix" {
  description = "Containers DNS server IP address."
  default     = "15.0.0.0/16"
}

variable "app_gateway_subnet_address_prefix" {
  description = "Containers DNS server IP address."
  default     = "15.1.0.0/16"
}

variable "app_gateway_name" {
  description = "Name of the Application Gateway."
  default     = "ApplicationGateway1"
}

variable "app_gateway_sku" {
  description = "Name of the Application Gateway SKU."
  default = "Standard_v2"
}

variable "app_gateway_tier" {
  description = "Tier of the Application Gateway SKU."
  default = "Standard_v2"
}

variable "identity" {
  description = "Managed Identity"
  default     = "identity"
}

variable "ip_allocation_method" {
  description = "IP Allocation Method"
  default     = "Static"
}
variable "ip_sku" {
  description = "IP SKU"
  default     = "Standard"
}

variable "app_gateway_subnet"{
  description = "App Gateway subnet"
  default     = "appgwsubnet"
}

variable "app_gateway_ip_config_name"{
  description = "App Gateway IP Config Name"
  default     = "appGatewayIpConfig"
}
variable "app_gateway_backend_http_settings_cookie_affinity"{
  description = "App Gateway BackEnd Http Settings Cookie Afinity"
  default     = "Disabled"
}
variable "app_gateway_backend_http_settings_port"{
  description = "App Gateway BackEnd Http Settings Port"
  default     = 80
}

variable "app_gateway_backend_http_settings_request_timeout"{
  description = "App Gateway BackEnd Http Settings Request Timeout"
  default     = 1
}

variable "app_gateway_backend_http_settings_protocol"{
  description = "App Gateway BackEnd Http Settings Protocol"
  default     = "Http"
}

variable "app_gateway_http_listener_protocol"{
  description = "App Gateway Http Listener Protocol"
  default     = "Http"
}

variable "app_gateway_http_listener_require_sni"{
  description = "App Gateway Http Listener Require SNI"
  default     = true
}

variable "app_gateway_request_routing_rule_type"{
  description = "App Gateway Request Routing Rule Type"
  default     = "Basic"
}

variable "aks_name" {
  description = "Name of the AKS cluster."
}
variable "aks_dns_prefix" {
  description = "Optional DNS prefix to use with hosted Kubernetes API server FQDN."
  default     = "aks"
}



variable "aks_agent_os_disk_size" {
  description = "Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 applies the default disk size for that agentVMSize."
  default     = 40
}

variable "aks_agent_count" {
  description = "The number of agent nodes for the cluster."
  default     = 1
}

variable "aks_agent_vm_size" {
  description = "The size of the Virtual Machine."
  default     = "Standard_D2_v2"
}

variable "kubernetes_version" {
  description = "The version of Kubernetes."
  default     = "1.15.2"
}

variable "aks_service_cidr" {
  description = "A CIDR notation IP range from which to assign service cluster IPs."
  default     = "10.0.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "Containers DNS server IP address."
  default     = "10.0.0.10"
}

variable "aks_docker_bridge_cidr" {
  description = "A CIDR notation IP for Docker bridge."
  default     = "172.17.0.1/16"
}

variable "aks_enable_rbac" {
  description = "Enable RBAC on the AKS cluster. Defaults to false."
  default     = "false"
}

variable "vm_user_name" {
  description = "User name for the VM"
  default     = "vmuser1"
}

variable "public_ssh_key_path" {
  description = "Public key path for SSH."
  default     = "~/.ssh/id_rsa.pub"
}


variable "domain_name" {
  description = "Domain Name."
}
variable "tags" {
  type = "map"

  default = {
    source = "terraform"
  }
}