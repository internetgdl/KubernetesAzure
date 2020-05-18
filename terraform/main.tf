provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you are using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
      subscription_id = var.aks_service_subscription_id
      client_id       = var.aks_service_principal_app_id
      client_secret   = var.aks_service_principal_client_secret
      tenant_id       = var.aks_service_principal_tenant_id
    features {}
}

terraform {
    backend "azurerm" {}
}