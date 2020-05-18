# Implementing a container cloud architecture. 

#### We will deploy application in Dotnet Core 3.1 in Docker Containers to Container Registry in Azure, creating a Kubernetes Cluster with Terraform and Helm for internal routing and management of open authority certificates with integration with our own domain and continued delivery in Microsoft DevOps


## Introduction:
#### The evolution of technology, the decentralization of data, the speed of innovation, adaptation to changes, has led us to think of a new way of developing software, which has led us to a new way of designing our solutions.
#### The cloud paradigm has made us rethink the correct use of resources.
#### The container architecture allows us to have small instances of our software components, but in order to achieve this we need to understand how they are orchestrated, managed, deployed, they grow, or they are reduced, etc.
#### In this tutorial we are going to work with one of the largest cloud service providers, and we will implement a container architecture, at the same time we will implement it with Terraform.


## 1. Requirements

#### In this scenario we are going to work with windows computers Using Visual Studio Code using PowerShell as Console

Visual Studio Code
https://code.visualstudio.com/

Dotnet Core SDK 3.1
https://dotnet.microsoft.com/download/dotnet-core/thank-you/sdk-3.1.201-windows-x64-installer

Git
https://github.com/git-for-windows/git/releases/download/v2.26.2.windows.1/Git-2.26.2-64-bit.exe

Docker

https://docs.docker.com/docker-for-windows/install/

* Note that Docker installation requires that they enable Hypertreading on their machines, verify that docker is running

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/0.JPG?raw=true)

Azure Cli

https://docs.microsoft.com/es-es/cli/azure/install-azure-cli-windows?view=azure-cli-latest#install-or-update

Kubernetes

`Install-Script -Name install-kubectl -Scope CurrentUser -Force`
`install-kubectl.ps1`

Choco, to install Terraform

`Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))`

Terraform
`$ choco install terraform`

## 2. Create project

Create a new folder to work
`mkdir myproject`
`cd myproject`

Now we will create a new application using DotNet Core and specifying the Web App template, this will create a folder with everything necessary for our first application.
`dotnet new webapp`

Now we restore the solution so that it implements the packages of the dependencies that we could have.
`dotnet restore ./`

Build the solution.
`dotnet build ./`

Publish the solution, it will create a folder with the binaries in a folder within our project bin/Release/netcoreapp3.1/publish/
`dotnet publish -c Release`

If we want to see our solution running we execute the following command and open our browser on localhost in the indicated port.
`dotnet run  ./`

## 3. Mount it inside a Docker container on our local machine

Inside our project we create a file called Dockerfile
`New-Item -Path './Dockerfile' -ItemType File`

We open the file with Visual Studio Code
`code ./Dockerfile`


We copy the following code, replacing the tag with the name of our project
```
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1

COPY bin/Release/netcoreapp3.1/publish/ App/
WORKDIR /App
ENTRYPOINT ["dotnet", "myproject.dll"]

```
In the previous code the first line tells us that we are going to take the image published by Microsoft for aspnet Projects in DotNetCore 3.1
In the next block of lines we specify that we are going to copy the content of our publication folder, that is, the binaries inside a folder called App/ and we put a ENTRYPOINT to run "dotnet myproject.dll" at startup.

Now we return to the console in the same path where our Dockerfile is, we built it and labeled it with version one
`docker build ./ --tag "myproject:1"`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/1.JPG?raw=true)

With the above docker will build an image which we can see if we execute
`docker images`

To get inside the cluster and run the image, run
`docker run -it -p 80:80 myproject:1`

With the previous one, Docker will implement the image inside a container, where with -p we specify that it will map port 80 of our machine to port 80 of the container.

To see it working, we open our browser on localhost, we must make sure that there is no other application using port 80, failing that we can map some other port.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/2.JPG?raw=true)


If we want to see the containers running we can run
`docker ps`


## 4.- Azure ACR


Now we will see how to connect to Azure from our terminal to create a group of resources and the Azure Container Registry (ACR) and upload our image of Docker.

Start session by running
`az login `
This will open a window in our browser and ask for the username and password, once validated it will close it and we return to our terminal to show us that we are inside.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/3.JPG?raw=true)


It will show us the subscriptions to which we have access, to see the default we can do it with
`az account show`

If the one that shows us is not the subscription in which we are going to work, then we specify it in a variable (good practice) and send it.
`$subscription =  "My Subscription"`
`az account set --subscription $subscription`

Now we are going to get the name, id and tenant of our subscription and assign it to variables, because we will need them later
```
$subscription = az account show --query name -o tsv
$subscriptionId = az account show --query id -o tsv
$tenant = az account show --query homeTenantId -o tsv
```

Now we create in variables what is the name of the resource group with which we are going to work and in another variable the geographical location of those available by azure, in this example we will work with eastus

```
$nameGrp = "myResourceGroup"
$location = "eastus"
```

Once defined we create the resource group
`az group create -l $location -n $nameGrp`
If we enter the portal we can see that it has been created correctly.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/4.JPG?raw=true)

Now we create the Azure Container Registry, (ACR) to store our docker images.

Define the name in one variable and in another the SKU with which it will be created`$acrname = "myacr"`
`$acrSKU = "Standard"`


Create it
`az acr create --name $acrName --resource-group $groupName --sku $acrSKU`
Enable the administration, which will allow us to connect from our Docker to upload the images
`az acr update --name $acrName --admin-enabled true`

Get the URL to login and assign it to a variable
`$acrURL = $(az acr show --name $acrName --resource-group $groupName --query loginServer -o tsv)`


Now we obtain in different variables the user and any of the two available keys
`$acrusername = az acr credential show -n $acrname --query username`
`$acrpassword = az acr credential show -n $acrname --query passwords[0].value`

We can already login or HandShake between our machine and the ACR with this and it will allow us to do the push from Docker
`az acr login --name $acrname --username $acrusername  --password $acrpassword`

Before doing push what we must do is re-label our local image with the name that the ACR will fear


Let's remember that we are saving the names in variables so that we can use them throughout our context
Name of image
`$imageName = "myproject"`
`$imageNameTag = "$imageName:1"`
We build the Url of the image which is the URL of the container plus "/" plus the name of our image and its label
`$imageUrl = $acrURL + "/" + $imageNameTag `
Label with Docker
`docker tag $imageNameTag $imageUrl`
Push the image
`docker push $containerurl`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/5.JPG?raw=true)

We can see the image inside Azure Portal.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/6.JPG?raw=true)

## 5.- Terraform

Now we will create our terraform environment to be able to deploy our Kubernetes cluster.

We go to the root of our solution and create a new folder where we will put our terraform project.
`cd ../`
`mkdir terraform`
`cd .\terraform\`

First we are going to create a file where we initialize terraform and put our provider, in this case "azurerm"
`New-Item -Path './main.tf' -ItemType File`

Note:
*This complete project can be seen inside the GIT repository that I have published https://github.com/internetgdl/KubernetesAzure

In the first file we put:

```
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
```

In the final block we initialize terraform and specify that our provider is "azurerm"F
In the provider block we specify the version, then the variables that we will need to implement are:
* subscription_id
* client_id
* client_secret
* tenant_id


These values ​​are the credentials of a user type Service Principal (SP) that we will create later

Now we create the variables file
`New-Item -Path './variables.tf' -ItemType File`
With content
```
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
```

Some variables do not have the default value specified, this is because we will pass them as a parameter later.
Some other variables specify how our kubernetes cluster is going to be created

For example, the DNS, GateWay, IP, the Version of the Kubernetes, the disk size, the number of replicas. In public_ssh_key_path you must specify a file the key to be able to connect to the linux machine from our local machine if it were to reach need

In order to create it, run ssh-keygen in our terminal, it will ask us for the password which we must write when we want to connect.
`ssh-keygen`


The configuration we use is the one proposed by Microsoft in its tutorial of creating Kubernetes cluster with terraform in https://docs.microsoft.com/en-us/azure/developer/terraform/create-k8s-cluster-with-tf-and-aks


Now we create the file where we define the resources that our kubernetes cluster will have

`New-Item -Path './resources.tf' -ItemType File`
With the content:
```
# # Locals block for hardcoded names. 
locals {
    backend_address_pool_name      = "${azurerm_virtual_network.test.name}-beap"
    frontend_port_name             = "${azurerm_virtual_network.test.name}-feport"
    backend_port_name              = "${azurerm_virtual_network.test.name}-beport"
    frontend_ip_configuration_name = "${azurerm_virtual_network.test.name}-feip"
    http_setting_name              = "${azurerm_virtual_network.test.name}-be-htst"
    listener_name                  = "${azurerm_virtual_network.test.name}-httplstn"
    request_routing_rule_name      = "${azurerm_virtual_network.test.name}-rqrt"
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# User Assigned Identities 
resource "azurerm_user_assigned_identity" "testIdentity" {
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  name                = var.identity

  tags                = var.tags
}

resource "azurerm_virtual_network" "test" {
  name                = var.virtual_network_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = [var.virtual_network_address_prefix]

  subnet {
    name           = var.aks_subnet_name
    address_prefix = var.aks_subnet_address_prefix
  }

  subnet {
    name           = var.app_gateway_subnet
    address_prefix = var.app_gateway_subnet_address_prefix
  }

  tags = var.tags
}

data "azurerm_subnet" "kubesubnet" {
  name                 = var.aks_subnet_name
  virtual_network_name = azurerm_virtual_network.test.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "appgwsubnet" {
  name                 = var.app_gateway_subnet
  virtual_network_name = azurerm_virtual_network.test.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

# Public Ip 
resource "azurerm_public_ip" "test" {
  name                         = "${var.resource_group_name}-ip"
  location                     = data.azurerm_resource_group.rg.location
  resource_group_name          = data.azurerm_resource_group.rg.name
  allocation_method            = var.ip_allocation_method
  sku                          = var.ip_sku
  domain_name_label            = var.domain_name
  tags                         = var.tags
}


resource "azurerm_application_gateway" "network" {
  name                = var.app_gateway_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  sku {
    name     = var.app_gateway_sku
    tier     = var.app_gateway_tier
    capacity = 2
  }

  gateway_ip_configuration {
    name      = var.app_gateway_ip_config_name
    subnet_id = data.azurerm_subnet.appgwsubnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_port {
    name = local.backend_port_name
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.test.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = var.app_gateway_backend_http_settings_cookie_affinity
    port                  = var.app_gateway_backend_http_settings_port
    protocol              = var.app_gateway_backend_http_settings_protocol
    request_timeout       = var.app_gateway_backend_http_settings_request_timeout
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = var.app_gateway_http_listener_protocol
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = var.app_gateway_request_routing_rule_type
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }

  
  tags = var.tags

  depends_on = ["azurerm_virtual_network.test", "azurerm_public_ip.test"]
}

resource "azurerm_role_assignment" "ra1" {
  scope                = data.azurerm_subnet.kubesubnet.id
  role_definition_name = "Network Contributor"
  principal_id         = var.aks_service_principal_object_id 

  depends_on = ["azurerm_virtual_network.test"]
}

resource "azurerm_role_assignment" "ra2" {
  scope                = azurerm_user_assigned_identity.testIdentity.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = var.aks_service_principal_object_id
  depends_on           = ["azurerm_user_assigned_identity.testIdentity"]
}

resource "azurerm_role_assignment" "ra3" {
  scope                = azurerm_application_gateway.network.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.testIdentity.principal_id
  depends_on           = ["azurerm_user_assigned_identity.testIdentity", "azurerm_application_gateway.network"]
}

resource "azurerm_role_assignment" "ra4" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.testIdentity.principal_id
  depends_on           = ["azurerm_user_assigned_identity.testIdentity", "azurerm_application_gateway.network"]
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name       = var.aks_name
  location   = data.azurerm_resource_group.rg.location
  dns_prefix = var.aks_dns_prefix

  resource_group_name = data.azurerm_resource_group.rg.name

  linux_profile {
    admin_username = var.vm_user_name

    ssh_key {
      key_data = file(var.public_ssh_key_path)
    }
  }

  addon_profile {
    http_application_routing {
      enabled = false
    }
  }

  default_node_pool {
    name            = "agentpool"
    node_count      = var.aks_agent_count
    vm_size         = var.aks_agent_vm_size
    os_disk_size_gb = var.aks_agent_os_disk_size
    vnet_subnet_id  = data.azurerm_subnet.kubesubnet.id
  }

  service_principal {
    client_id     = var.aks_service_principal_app_id
    client_secret = var.aks_service_principal_client_secret
  }

  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = var.aks_dns_service_ip
    docker_bridge_cidr = var.aks_docker_bridge_cidr
    service_cidr       = var.aks_service_cidr
  }

  depends_on = ["azurerm_virtual_network.test", "azurerm_application_gateway.network"]
  tags       = var.tags
}


```
Most references are obtained from other resources on which they depend, others from variables.

Finally we create the file output.tf which is where we are going to define values ​​in variables that terraform creates on kubernetes in Azure and that we can consult from the context.

`New-Item -Path './resources.tf' -ItemType File`
With the content
```
output "client_key" {
    value = azurerm_kubernetes_cluster.k8s.kube_config.0.client_key
}

output "client_certificate" {
    value = azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate
}

output "cluster_ca_certificate" {
    value = azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate
}

output "cluster_username" {
    value = azurerm_kubernetes_cluster.k8s.kube_config.0.username
}

output "cluster_password" {
    value = azurerm_kubernetes_cluster.k8s.kube_config.0.password
}

output "kube_config" {
    value = azurerm_kubernetes_cluster.k8s.kube_config_raw
}

output "host" {
    value = azurerm_kubernetes_cluster.k8s.kube_config.0.host
}

output "identity_resource_id" {
    value = azurerm_user_assigned_identity.testIdentity.id
}

output "identity_client_id" {
    value = azurerm_user_assigned_identity.testIdentity.client_id
}
```
We can access these variables from our terminal to later deploy or create resources related to this cluster.


So far we already have our entire cluster defined.

Now we must initialize it, this process will analyze our structure and save the "state".

We can save the state on our local computer, but in this exercise we will use Azure cli in Powershell to connect to Azure and create a Storage and Container to store the state.

We define in one variable the name of our Storage and in another the SKU that our storage will have

`$storageName = "myStorage"`
`$storageSKU = "Standard_LRS"`

We create the storage in Azure
`az storage account create --name $storageName --resource-group $nameGrp --sku $storageSKU`

Once created we get the ConnectioString to create the container where the state of our terraform will be
`$storageKey=(az storage account keys list -n $storageName -g $nameGrp --query [0].value -o tsv)`

Now we define the name of our container and proceed to create it
`$containerStateName "stateOfMyTerraform"`
`az storage container create -n $containerStateName --account-name $storageName --account-key $storageKey`

We can see the resources we create on our Azure portal

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/7.JPG?raw=true)


Now as we specify within the provider and before creating our Cluster we must specify the credentials of the Service Principal User (SP) who will create all the resources within our Azure subscription, this must be a user with high privileges.

Now we will create this user with Azure Cli

Create the user and at the moment of creation we structure the response so that it only gives us the pasword in a flat way and assigns it to a variable.
In this instruction we are already specifying that your role will be "Owner" for the subscription that we have in context.
$spPassword = az ad sp create-for-rbac -n $spName --role "Owner" --query password --output tsv

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/8.JPG?raw=true)

Once the user is created, we make queries to obtain the AppID and the ObjectID and assign it in variables.

$spId = az ad sp list --filter "displayname eq '$spName'" --query '[].appId' -o tsv
$spObjectId = az ad sp list --filter "displayname eq '$spName'"  --query '[].objectId' -o tsv

Go ahead, we are going to create a variable structure with information that we have defined throughout this tutorial in context, because they will help us define our cluster.

Define the name of our cluster$aksName = "myAKS"
Define the domain that we will use, because we are going to specify a dns that we can identify later
$dnsName = "mypersonaldomain123.com"

Define the name of the Gateway because we use it later.

```
$varInitial = '' # empty var so that a subsequent join does not affect us.
$varResourceName = 'resource_group_name={0}' -f $groupName # the resource group to the kubernetes where it will be created
$varSubscriptionId = 'aks_service_subscription_id={0}' -f $subscriptionId # Subscription Id
$varSpUserName = 'aks_service_principal_app_id={0}' -f $spId # Service Principal ID just created
$varSpPassword = 'aks_service_principal_client_secret={0}' -f $spPassword # Client Secret
$varSpObjectId = 'aks_service_principal_object_id={0}' -f $spObjectId # Object ID of the SP
$varTenant = 'aks_service_principal_tenant_id={0}' -f $tenant # Tenant of the subscription
$varLocation = 'location={0}' -f $location # The location
$varAksName = 'aks_name={0}' -f $aksName # The Name of AKS
$varDns = 'domain_name={0}' -f $dnsName.replace(".","") # 
The domain without points, to define it as DNS of the Cluster would be something like mypersonaldomain123.eastus.cloudapp.azure.com
```

Defines the name of the plan in a variable
`$planName = "plan.out"`

Build all the variables in a format where each one has a -var prefix (that's why the variable empties at the beginning)
`$planCmdVars = $varInitial, $varResourceName, $varSubscriptionId, $varSpUserName, $varSpPassword, $varSpObjectId, $varTenant, $varLocation, $varAksName, $varDns -join ' -var '`

Proceed to create our cluster by starting Terraform, as we said we specify the configuration to save our backend, sending the connectionstring the name of our storage and that of the container

`terraform init -backend-config="storage_account_name=$storageName" -backend-config="container_name=$containerStateName" -backend-config="access_key=$storageKey" -backend-config="key=codelab.microsoft.tfstate"`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/9.JPG?raw=true)

We can see that it created a folder with the information of our state and our provider, if there had been a problem at the start, terraform would tell us in a very explicit way, correct the problem, delete the folder and initialize it again


Now we create our plan, but we will execute it by means of PowerShell Invoke-Expression due to the fact that it has a terraform variable structure inside a PowerShell variable

`Invoke-Expression -Command "terraform plan --out $planName  -input=false -detailed-exitcode $planCmdVars"`

The output of in the file system.
![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/10.JPG?raw=true)

The output of the console.
![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/11.JPG?raw=true)


Finally we apply the plan, this will take a few minutes

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/12.JPG?raw=true)

In the end I'll show
![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/13.JPG?raw=true)

Viewing from Azure

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/14.JPG?raw=true)

We'll see the virtual networ, kubernetes cluster, public IP, and a Identity created by Kuberneres plus the ACR, the storage previusly created in this tutorial

As we can see in the creation of the ALS, Azure created a new group of resources where its name is structured something like this: MC_myaks_eastus with the resources that the cluster will need for its operations, such as a load balancer and other resources that we need and supply with the operation of our cluster.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/15.JPG?raw=true)

### 6. Kubernetes

Now we can start creating deployments of Kubernetes, Services, etc.

But before we start with that, let's explain what is Kubernetes.
Kubernetes is a container orchestrator
By object called deployment, Kubernetes manage the pods that have the containers that have our created images, this object is defined in a yaml file which we must create and provision with kubernetes.

Within the same Yaml we will create the service to define the network configuration in our cluster that allows us to access those pods.

Right now we have the basics that a Kubernetes cluster requires:
* Pods created using a replica restructure defined and managed by our deploy object
* Services that define on the cluster which ports point to which deployment

We will create our first deployment and service

In order to interact with Kubernetes in our Azure (AKS) we must establish that relationship of trust (HandShake)

For what we execute

`az aks get-credentials --resource-group $groupName --name $aksName`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/16.JPG?raw=true)

Go to the root of our solution and create a folder ca where we will put our yamls and enter

```
cd ..
mkdir yaml
cd ./yaml

```

Create a file to define our deployment and the service of this deployment.
`New-Item -Path './Deploymeny-Service.yaml' -ItemType File` `
With the content.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myimage
  labels:
    app: myimage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myimage
  template:
    metadata:
      labels:
        app: myimage
    spec:
      containers:
        - name: myimage
          image: myacr.azurecr.io/myproject:1
          ports:
            - containerPort: 80
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: dev
---
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/azure-dns-label-name: myimage321
  name: myimage-service
spec:
  type: LoadBalancer
  ports:
   - port: 80
  selector:
    app: eduardomx
```
In the previous code block, the kind Deployment defines that we are going to start a new definition for a Deployment.

The attributes that we are going to replace are:

* name: myimage // which is how it will be identified within the cluster, to continue with the same standard we will put the same name that we put to our local docker "myimage" defined in the variable $imageName.
* replicas: 1 // it goes within spect and it is how many replicas this service will be able to have, that is, the number of pods it can create to manage its scalability.
* image:  myacr.azurecr.io/myproject:1 // The url of the image inside the ACR as previously defined, we have this in the variable.


the "---" indicator specifies that we are going to start with another object; the following we are going to create a service defining the kind: Service.

The attributes that we are going to replace are
* name: myimage-service // we define what our service will be called
* service.beta.kubernetes.io/azure-dns-label-name: myimage321 // 
it must be and unique name to create the dns inside of Azure Region and associate with the public created IP
* app: myimage321 // the name of the created deployment

Guardamos el archivo y las aplicaciones con Kubernetes.

`kubectl apply -f .\eduardo.yaml Deploymeny-Service.yaml`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/17.JPG?raw=true)

In order to see the created pods from the terminal, we execute.

`kubectl get pods`

To be able to see the deployments.

`kubectl get deployments`

To see the services

`kubectl get services`

Here we can see the external IP
![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/18.JPG?raw=true)

Likewise we can ask Kubernetes to describe each object, to describe the service we execute.

`kubectl describe services myimage-service`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/19.JPG?raw=true)

If there are no errors, it will show us the dns label and we will be able to show our application from the browser, leaving a url composed of the name of dns that we define, the region and the domain of apps from Azure "http://myimage321.eastus.cloudapp.azure.com/"

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/20.JPG?raw=true)

A useful tool to manage the cluster is the Terraform Board, to start it we execute.

`az aks browse --resource-group $groupName  --name $aksName`
This will not open a browser window.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/21.JPG?raw=true)

## 7. DNS, Routing and Certificates 

To be able to orchestrate with Kubernetes a solution that allows us to create call routes to our DNS between our services and manage security certificates, another series of elements are needed, such as routing, load balancer, certificate manager and the cluster of emission of certificates.


These elements are managed with Helm they are known as charts, to understand it a little better Helm is like a package manager and each chart is a package.


For this example we will install two packages.

* nginx-ingress
* cert-manager

The nginx-ingress chart is found in the google apis namespace https://kubernetes-charts.storage.googleapis.com/ and allows us to create the ingress objects for our services, which defines the route that requests should take if they come under certain criteria, for example a subdomain, or an internal domain path (eduardo.mydomain.com or mydomain.com/eduardo or * .mydomain.com).

The cert-manager chart is in the jetstack repo https://charts.jetstack.io this will help us create a certificate issuing cluster, when the ingress of a service specifies that a service must have a tls , you will have to define your name and the type of issuer, in this example we will use letsencrypt, which is an open and free certification scheme, but you can also define certificates issued by a certificate entity or some external certificate service.

The installation of these repos will be done within another cluster namespace so that we can facilitate the operation when we have a large number of services.

`kubectl create namespace ingress-basic`

Add the Google Apis repo.
`helm repo add stable https://kubernetes-charts.storage.googleapis.com/`

install nginx-ingress.
`helm install nginx stable/nginx-ingress --namespace ingress-basic --set controller.replicaCount=2 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux`

Validate and save the external IP of the controller.

`kubectl get service -l app=nginx-ingress --namespace ingress-basic`


Another chat that we need is the Custom Resource Definition that allows you to define custom resources.

`kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.13/deploy/manifests/00-crds.yaml`

Now we must to disable the resource validation for ingress.
`kubectl label namespace ingress-basic cert-manager.io/disable-validation=true`


Now we are going to install the Certificate Manager Cert-Manager.

We added the Jetstack repo.
`helm repo add jetstack https://charts.jetstack.io`

Update.
`helm repo update`

Just like with nginx we install it inside the ingress-basic namespace.
`helm install cert-manager --namespace ingress-basic --version v0.13.0 jetstack/cert-manager`

Validate that we have the pods installed under the ingress-basic namespace.
`kubectl get pods --namespace ingress-basic`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/22.JPG?raw=true)

Create the DNS Zone for our domain.

`az network dns zone create --name $dnsName --resource-group $groupName --zone-type public`

Get the NS Urls, to set to our domain in the system where do you buy your domain.

`az network dns zone show --name $dnsName --resource-group $groupName --query "nameServers"  --output tsv`

We point our domain to those DNS.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/23.JPG?raw=true)

Add and "A" record-set to the record-set of the DNS Zone with the IP of our balancer.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/24.JPG?raw=true)

`az network dns record-set a add-record --resource-group $groupName --zone-name "ku2.com.mx" --record-set-name '*' --ipv4-address 52.191.81.204`

We can see the area and the registration in the Azure Portal.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/25.JPG?raw=true)

Now we are going to work with the Certificate Manager, first we are going to create an issuing cluster, this will not allow us to issue certificates when we create ingress elements for the services that we will publish in Kubernetes.

The cluster will create the certificates using the LetsEncrypt certification authority.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/26.JPG?raw=true)

The way to create these elements is the same, creating their definitions in yaml format.

For the cluster, being in our yaml path we create a file called clusterissuer.yaml

`New-Item -Path './clusterissuer.yaml' -ItemType File`

With the content:

```
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: your@email.com
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          class: nginx
```

* The element "name" identifies the name of our cluster.
* "email" we have to define our email.
* The other elements we leave them the same.

Apply
`kubectl apply -f .\clusterissuer.yaml`

Now we will delete the previously created service to re-create it with a modification that will allow us to maintain traffic only by the ingress.

In the service we had to define the type of service as.
`kubectl delete -f .\eduardo.yaml Deploymeny-Service.yaml`

In the Service we change the type: LoadBalancer by type: ClusterIP, so that it is as follows:

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myimage
  labels:
    app: myimage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myimage
  template:
    metadata:
      labels:
        app: myimage
    spec:
      containers:
        - name: myimage
          image: myacr.azurecr.io/myproject:1
          ports:
            - containerPort: 80
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: dev
---
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/azure-dns-label-name: myimage321
  name: myimage-service
spec:
  type: ClusterIP
  ports:
   - port: 80
  selector:
    app: eduardomx
```
* type: ClusterIP // This will not create public ip

We apply deploy and service again.

`kubectl delete -f .\eduardo.yaml Deploymeny-Service.yaml`

Now we create the ingress that will not allow to create the certificate and direct the traffic.

We create a file called ingress.

`New-Item -Path './clusterissuer.yaml' -ItemType File`

With the content:
```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: myimage-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - myimage.mypersonaldomain123.com
    secretName: myimage-secret
  rules:
  - host: myimage.mypersonaldomain123.com
    http:
      paths:
      - backend:
          serviceName: myimage-service
          servicePort: 80
        path: /(.*)
```

The important elements are:

* name: myimage-ingress // el nombre del ingress
* cert-manager.io/cluster-issuer: letsencrypt // el nombre de nuestro cluster de emision
* hosts:
	* myimage.mypersonaldomain123.com // sobre que llamada se enturará el tráfico y también se le especifica en el tls para la creación del dominio
* secretName: myimage-secret // el nombre del certificado en nuestro administrador de certificados
* host: myimage.mypersonaldomain123.com // también se define en las reglas
*  backend:
	* serviceName: myimage-service // el nombre que tiene nuestro servicio
* path: /(.*) // la expresión por la cual se aplica el redireccionamiento de tráfico


`kubectl apply -f .\eduardoingress.yaml`


We validate and wait for the certificate to be created
`kubectl get certificates --namespace ingress-basic`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/27.JPG?raw=true)

Now we can enter the browser, open our URL and validate the certificate

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/28.JPG?raw=true)

With this we have finished "creating an application with DotNetCore 3.1, put it inside a Docker, upload it to an ACR, Create an AKS cluster with Kubernetes, Deploy Deployments, Services. Install an nginx Ingress route handler and certificate manager with LetsEncrypt with Helm."


So if you have any questions please feel free to contact me.

* Email: eduardo@eduardo.mx
* Web: [Eduardo Estrada](http://eduardo.mx "Eduardo Estrada")
* Twitter: [Twiter Eduardo Estrada](https://twitter.com/internetgdl "Twiter Eduardo Estrada")
* LinkedIn: https://www.linkedin.com/in/luis-eduardo-estrada/
* GitHub: [GitHub Eduardo Estrada](https://github.com/internetgdl "GitHub Eduardo Estrada")
* Eduardo Estrada
