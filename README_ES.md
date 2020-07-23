# Implementando arquitectura de contenedores en la nube.

#### En este articulo deployaremos una aplicación en DotNet Core 3.1 dentro de un contenedor de Docker a Container Registry en Azure, creando un Cluster de Kubernetes Cluster con Terraform y Helm para el routeo interno y la administración de los certificados de open authority integrado con nuestro dominio e integrando con Azure DevOps


## Introducción:
#### La evolución de la tecnología, la descentralización de los datos, la velocidad de la innovación, adaptación a los cambios, nos ha llevado a evolucionar en la forma en que desarrollamos el software y lo aprovisionamos.
#### EL paradigma de la nube nos ha llevado a pensar si la forma en que usamos los recursos es la correcta.
#### La arquitectura de contenedores nos permite tener muchas pequeñas instancia de los componentes de software que asumiendo están desarrollados de forma desacoplada, tenemos que desarrollar las metodologías para la correcta orquestación, para administrarlos, desplegarlos, gestionar los costos, optimizar el performance, etc.
#### En este tutorial veremos la forma de aprovisionar en uno de los más grandes providers de cómputo en la nube como lo es Microsoft Azure una infraestructura de contenedores con Terraform.


## 1. Requerimientos

#### En este escenario vamos a trabajar en un ambiente local de Windows usando Visual Studio Code con PowerShell como consola

Visual Studio Code
https://code.visualstudio.com/

DotNet Core SDK 3.1
https://dotnet.microsoft.com/download/dotnet-core/thank-you/sdk-3.1.201-windows-x64-installer

Git
https://github.com/git-for-windows/git/releases/download/v2.26.2.windows.1/Git-2.26.2-64-bit.exe

Docker

https://docs.docker.com/docker-for-windows/install/

* Docker requiere que se habilite Hypertreading en sus máquinas; verifica que Docker ese corriendo

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/0.JPG?raw=true)

Azure Cli

https://docs.microsoft.com/es-es/cli/azure/install-azure-cli-windows?view=azure-cli-latest#install-or-update

Kubernetes

`Install-Script -Name install-kubectl -Scope CurrentUser -Force`
`install-kubectl.ps1`

Choco, para instalar Terraform

`Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))`

Terraform
`$ choco install terraform`

## 2. Crear el proyecto

Crea una nueva carpeta donde instalaremos el proyecto.
`mkdir myproject`
`cd myproject`

Ahora crearemos una nueva aplicación usando DotNet Core y especificando la plantilla "Web App", esto les creará una carpeta con todo lo necesario para correr nuestra primera aplicación.
`dotnet new webapp`

Ahora restauraremos la aplicación para obtener las dependencias que esta requiere.
`dotnet restore ./`

Construimos la aplicación.
`dotnet build ./`

Publicamos la solución, nos creará una carpeta con los binarios dentro de nuestra solución bin/Release/netcoreapp3.1/publish/
`dotnet publish -c Release`

SI deseamos ver nuestra solución corriendo ejecutaremos el siguiente comando y abriremos el navegador indicando la URL de localhost y el puerto requerido.
`dotnet run  ./`

## 3. Montamos este dentro de un contenedor de Docker en nuestra maquina local

Dentro de nuestro proyecto crearemos un archivo llamado Dockerfile
`New-Item -Path './Dockerfile' -ItemType File`

Abrimos el archivo con Visual Studio Code
`code ./Dockerfile`


Ahora copiaremos el siguiente código remplazando la línea de ENTRYPOINT con la dll principal de nuestro proyecto.
```
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1

COPY bin/Release/netcoreapp3.1/publish/ App/
WORKDIR /App
ENTRYPOINT ["dotnet", "myproject.dll"]

```
En el código anterior la primera línea nos dice que vamos a tomar la imagen pública  de Microsoft para proyectos ASPNet en DotNet Core 3.1
En el siguiente bloque de lineas especificaremos que vamos a copiar el contenido de la carpeta de publicación de nuestro proyecto, que son los binarios a la carpeta llamada App/ y finalmente ponemos ENTRYPOINT para correr "dotnet myproject.dll" al iniciar la imagen.

Ahora regresamos a la consola en la misma ruta donde se encuentra nuestro archivo Dockerfile, construiremos y etiquetaremos con la versión uno.
`docker build ./ --tag "myproject:1"`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/1.JPG?raw=true)

Con la siguiente línea veremos las imágenes que ha construido Docker
`docker images`

Para ejecutar la imagen ejecutamos la siguiente línea:
`docker run -it -p 80:80 myproject:1`

En la línea anterior estamos implementando la imagen dentro de un contenedor, donde el argumento -p especifica que el puerto 80 de nuestra maquina enrutara las peticiones al puerto 80 del contenedor.

Para verlo corriendo, abriremos la URL de nuestro navegador en localhost, debemos de asegurarnos que otra aplicación no este usando el puerto 80, de cualquier forma, podríamos especificar otro puerto.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/2.JPG?raw=true)


Si deseamos ver los contenedores corriendo ejecutamos
`docker ps`


## 4.- Azure ACR (Azure Container Registry)


Ahora veremos como conectar Azure desde nuestra terminal para crear un grupo de recursos, un Azure Container Registry (ACR) y subir nuestra imagen de Docker.

Iniciamos la sesión corriendo
`az login `
Esto nos abrirá una nueva ventana en nuestro navegador y nos solicitará el usuario y la contraseña, una vez validado podremos regresar a la terminal.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/3.JPG?raw=true)


Nos mostrará las subscripciones a las que tenemos acceso, para ver la subscripción predeterminada lo podemos hacer con:
`az account show`

Si esta no es con la que trabajaremos podemos especificarla en una variable (buena práctica) y cambiarnos estableciéndola como argumento de la siguiente forma:
`$subscription =  "My Subscription"`
`az account set --subscription $subscription`

Ahora obtendremos el nombre, id y tenant de nuestra subscripción y la asignaremos dentro de variables porque las necesitaremos mas adelante.
```
$subscription = az account show --query name -o tsv
$subscriptionId = az account show --query id -o tsv
$tenant = az account show --query homeTenantId -o tsv
```

Ahora crearemos en las variables cual será el nombre de nuestro grupo de recursos con el que vamos a trabajar, de igual forma establecemos en otra variable la ubicación geográfica como lo define Azure en este ejemplo usaremos "eastus"

```
$nameGrp = "myResourceGroup"
$location = "eastus"
```

Una vez definida creamos el grupo de recursos.
`az group create -l $location -n $nameGrp`

Si entramos a portal podremos ver que se han creado correctamente.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/4.JPG?raw=true)

Ahora crearemos el Azure Container Registry, (ACR) para almacenar nuestras imágenes Docker.

Define el nombre en una variable y en otra el SKU de nuestro ACR
`$acrname = "myacr"`
`$acrSKU = "Standard"`


Lo creamos
`az acr create --name $acrName --resource-group $groupName --sku $acrSKU`
Habilotamos la administración, esto nos permitirá conectarnos desde nuestra terminal para subir las imagenes.
`az acr update --name $acrName --admin-enabled true`

Obtenemos la URL para hacer login y la asignamos a una variable
`$acrURL = $(az acr show --name $acrName --resource-group $groupName --query loginServer -o tsv)`


Ahora obtenemos en distintas variables el usuario la contraseña.
`$acrusername = az acr credential show -n $acrname --query username`
`$acrpassword = az acr credential show -n $acrname --query passwords[0].value`

Ahora podemos hacer login o "HandShake" entre nuestra maquina y el ACR esto nos permitirá subir nuestra imagen con "push"
`az acr login --name $acrname --username $acrusername  --password $acrpassword`

Antes de hacer push debemos re-etiquetar nuestra imagen local con el nombre del ACR que la almacenará.


Recordaremos que estamos guardando todos los argumentos en variables para tenerlas disponibles durante nuestra sesión de trabajo en nuestra terminal.

`$imageName = "myproject"`
`$imageNameTag = "$imageName:1"`

Ahora construiremos como debe de ir la URL del ACR más  "/" más el nombre de nuestra imagen y esta será nuestra etiqueta.
`$imageUrl = $acrURL + "/" + $imageNameTag `
Etiquetamos con Docker
`docker tag $imageNameTag $imageUrl`
Hacemos Push a la imágen
`docker push $containerurl`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/5.JPG?raw=true)

Ahora podemos ver la imagen dentro del portal de Azure.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/6.JPG?raw=true)

## 5.- Terraform

En este apartado crearemos el cluster de Kubernetes usando Terraform

Nos ubicamos en la raíz de nuestra solución y creamos una nueva carpeta donde definiremos nuestro proyecto de Terraform.
`cd ../`
`mkdir terraform`
`cd .\terraform\`

Creamos el archivo donde comenzaremos con las instrucciones de Terraform, primero el provider en este caso "azurerm"
`New-Item -Path './main.tf' -ItemType File`

Nota:
*El proyecto completo se puede ver dentro de este mismo repositorio, la URL es https://github.com/internetgdl/KubernetesAzure

Para configurar nuestro provider:

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

Al final del bloque inicializaremos Terraforma y especificaremos nuestro proovedor que es "azurerm"
En el bloque del proveedor especificamos, la versión enseguida las variables que usaremos la implementación, son:
* subscription_id
* client_id
* client_secret
* tenant_id


Estos valores son las credenciales que deben de ser tipo User Principal (SP) que son con las que utilizará el cluster para crear los elementos en Azure.

Ahora crearemos el archivo de las variables.
`New-Item -Path './variables.tf' -ItemType File`
Con el contenido
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

Algunas variables no tienen el valor predeterminado especificado, esto es porque se las pasaremos posteriormente como parámetro por temas de seguridad.
Algunas otras variables determinan como es que el Cluster será creado.

Por ejemplo, las DNS, GateWay, IP, la Versión de Kubernetes, el tamaño de disco, el número de replicas, etc. En public_ssh_key_path debes de especificar el path del archivo llave que podrás utilizar para hacer handshake con la máquina de Linux que se aprovisionará para el cluster.

Para poder crear la llave ejecutamos ssh-keygen en nuestra terminal (Linux o Putty), Nos preguntara el password que tendremos que especificar cuando nos conectemos.
`ssh-keygen`


La configuración que usamos en la propuesta por Microsoft "creating Kubernetes cluster with terraform" en: https://docs.microsoft.com/en-us/azure/developer/terraform/create-k8s-cluster-with-tf-and-aks


Ahora creamos el archivo donde se definen las características que nuestro cluster debe de tener

`New-Item -Path './resources.tf' -ItemType File`
Con el contenido:
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
Muchas referencias son obtenidas de otros recursos de los cuales dependen y se definen y acceden a ellos como variables u objetos.

Ahora crearemos el archivo output.tf en el que definiremos variables las cuales podremos consultar desde el contexto

`New-Item -Path './output.tf' -ItemType File`
Con el contenido
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
Ahora podemos acceder a estas variables desde nuestra terminal para utilizarlas en el deploy o crear otros elementos relacionados a este Cluster.


Ahora ya tenemos el Cluster completo definido.

Inicializaremos el mismo, este proceso analizará la estructura y guardará el estado "state"

Podemos guardar el estado en nuestro equipo local, pero en este ejercicio usaremos Azure Cli para conectarnos a Azure y crearemos un Storage and Container para almacenar el estado.

Definiremos en una variable el nombre de nuestro Storage y en otra el SKU que nuestro recurso deberá tener.

`$storageName = "myStorage"`
`$storageSKU = "Standard_LRS"`

Lo creamos en Azure
`az storage account create --name $storageName --resource-group $nameGrp --sku $storageSKU`

Una vez creado obtendremos el ConnectioString para crear el contenedor donde estará el estado del Terraform
`$storageKey=(az storage account keys list -n $storageName -g $nameGrp --query [0].value -o tsv)`

Ahora definiremos el nombre de nuestro contenedor y procederemos a crearlo.
`$containerStateName "stateOfMyTerraform"`
`az storage container create -n $containerStateName --account-name $storageName --account-key $storageKey`

Ahora veremos los recursos que se crearán en nuestro portal de Azure.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/7.JPG?raw=true)


Ahora como lo especificamos en el provider y antes de crear el Cluster debemos de especificar las credenciales del Service Principal User (SP) con el que Terraform creará los recursos en nuestra subscripción de Azure, este debe de tener privilegios elevados.

Creamos el usuario con Azure Cli

Creamos el usuario y en el momento de la creación estructuramos para que la respuesta se almacene la contraseña en texto plano y nos lo asigne a una variable.
En esta instrucción estaremos especificando que el rol debe de ser "Owner".
$spPassword = az ad sp create-for-rbac -n $spName --role "Owner" --query password --output tsv

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/8.JPG?raw=true)

Una vez que el usuario es creado, obtenemos el AppID y el ObjectID y lo asignamos en dos variables.

$spId = az ad sp list --filter "displayname eq '$spName'" --query '[].appId' -o tsv
$spObjectId = az ad sp list --filter "displayname eq '$spName'"  --query '[].objectId' -o tsv

Adelante, vamos a seguir creando variables para almacenar los valores que podremos estar usando durante el tutorial.

Nombre del cluster
$aksName = "myAKS"
Definimos el dominio que usaremos, porque tendremos que especificarlo a las DNS posteriormente.
$dnsName = "mypersonaldomain123.com"

Define el nombre del Gateway porque lo usaremos después.

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

Define el nombre del plan en una variable
`$planName = "plan.out"`

Cree todas las variables en un formato donde cada una tenga un prefijo -var (es por eso que la variable se vacía al principio)
`$planCmdVars = $varInitial, $varResourceName, $varSubscriptionId, $varSpUserName, $varSpPassword, $varSpObjectId, $varTenant, $varLocation, $varAksName, $varDns -join ' -var '`

Para crear nuestro clúster, inicie Terraform, ya que dijimos que especificamos la configuración para guardar nuestro BackEnd, enviando a las conexiones el nombre de nuestro almacenamiento y el del contenedor.

`terraform init -backend-config="storage_account_name=$storageName" -backend-config="container_name=$containerStateName" -backend-config="access_key=$storageKey" -backend-config="key=codelab.microsoft.tfstate"`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/9.JPG?raw=true)

Podemos ver que creó una carpeta con la información de nuestro estado y nuestro proveedor, si hubiera habido un problema al principio, Terraform nos diría de una manera muy explícita, corregiría el problema, eliminaría la carpeta e inicializaría nuevamente.


Ahora creamos nuestro plan, pero lo ejecutaremos mediante PowerShell Invoke-Expression debido al hecho de que tiene una estructura de variable de terraforma dentro de una variable de PowerShell.

`Invoke-Expression -Command "terraform plan --out $planName  -input=false -detailed-exitcode $planCmdVars"`

La salida de en el sistema de archivos.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/10.JPG?raw=true)

La salida de la consola.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/11.JPG?raw=true)


Finalmente aplicamos el plan, esto tomará unos minutos

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/12.JPG?raw=true)

Al final te mostrará

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/13.JPG?raw=true)

Viendose desde Azure

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/14.JPG?raw=true)

Veremos la red virtual, el clúster de Kubernetes, la IP pública y una Identidad creada por Kuberneres más el ACR, el almacenamiento creado previamente en este tutorial.

Como podemos ver en la creación del ALS, Azure creó un nuevo grupo de recursos donde su nombre se estructura de la siguiente manera: MC_myaks_eastus con los recursos que el clúster necesitará para sus operaciones, como un equilibrador de carga y otros recursos que nosotros Necesidad y suministro con la operación de nuestro clúster.


![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/15.JPG?raw=true)

### 6. Kubernetes

Ahora podemos comenzar a crear implementaciones de Kubernetes, Servicios, etc.

Pero antes de comenzar con eso, expliquemos qué es Kubernetes.
Kubernetes es un orquestador de contenedores.
Por objeto llamado despliegue, Kubernetes gestiona los pods que tienen los contenedores que tienen nuestras imágenes creadas, este objeto se define en un archivo yaml que debemos crear y aprovisionar con kubernetes.

Dentro del mismo Yaml crearemos el servicio para definir la configuración de red en nuestro clúster que nos permite acceder a esos pods.

En este momento tenemos los conceptos básicos que requiere un clúster de Kubernetes:
* Pods creados usando una réplica reestructurada definida y administrada por nuestro objeto de implementación
* Servicios que definen en el clúster qué puertos apuntan a qué implementación

Crearemos nuestro primer despliegue y servicio

Para interactuar con Kubernetes en nuestro Azure (AKS) debemos establecer esa relación de confianza (HandShake)

Por lo que ejecutamos

`az aks get-credentials --resource-group $groupName --name $aksName`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/16.JPG?raw=true)

Vaya a la raíz de nuestra solución y cree una carpeta ca donde colocaremos nuestros yamls e ingresaremos

```
cd ..
mkdir yaml
cd ./yaml

```

Cree un archivo para definir nuestra implementación y el servicio de esta implementación.

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
    app: myimage
```

En el bloque de código anterior, el tipo de Implementación define que vamos a comenzar una nueva definición para una Implementación.

Los atributos que vamos a reemplazar son:

* name: myimage // así es como se identificará dentro del clúster, para continuar con el mismo estándar pondremos el mismo nombre que le ponemos a nuestra ventana acoplable local "myimage" definida en la variable $ imageName.
* replicas: 1 // va dentro del espectro y es cuántas réplicas podrá tener este servicio, es decir, la cantidad de pods que puede crear para administrar su escalabilidad.
* image: myacr.azurecr.io/myproject:1 // La url de la imagen dentro del ACR como se definió anteriormente, tenemos esto en la variable.


El indicador "---" especifica que vamos a comenzar con otro objeto; A continuación vamos a crear un servicio definiendo el tipo: Servicio.

Los atributos que vamos a reemplazar son
* name: myimage-service // definimos cómo se llamará nuestro servicio

* service.beta.kubernetes.io/azure-dns-label-name: myimage321 // 
debe ser un nombre único para crear el dns dentro de Azure Region y asociarlo con la IP pública creada
* app: myimage321 // el nombre del deployment creado

Guardamos el archivo y las aplicaciones con Kubernetes.

`kubectl apply -f .\Deploymeny-Service.yaml`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/17.JPG?raw=true)

Para ver los pods creados desde la terminal, ejecutamos.

`kubectl get pods`

Para poder ver las implementaciones.

`kubectl get deployments`

Para ver los servicios

`kubectl get services`

Aqui podemos ver la IP externa
![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/18.JPG?raw=true)

Del mismo modo, podemos pedirle a Kubernetes que describa cada objeto, que describa el servicio que ejecutamos.

`kubectl describe services myimage-service`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/19.JPG?raw=true)

Si no hay errores, nos mostrará la etiqueta dns y podremos mostrar nuestra aplicación desde el navegador, dejando una url compuesta por el nombre de dns que definimos, la región y el dominio de aplicaciones de Azure "http://myimage321.eastus.cloudapp.azure.com/"

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/20.JPG?raw=true)

Una herramienta útil para administrar el clúster es el Terraform Board, para iniciarlo lo ejecutamos.

`az aks browse --resource-group $groupName  --name $aksName`
Esto no abrirá una ventana del navegador.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/21.JPG?raw=true)

## 7. DNS, Routeo y Certificados

Para poder organizar con Kubernetes una solución que nos permite crear rutas de llamadas a nuestro DNS entre nuestros servicios y administrar certificados de seguridad, se necesitan otra serie de elementos, como enrutamiento, equilibrador de carga, administrador de certificados y el grupo de emisión de certificados .

Estos elementos se administran con Helm, se conocen como gráficos, para entenderlo un poco mejor Helm es como un administrador de paquetes y cada gráfico es un paquete.

Para este ejemplo instalaremos dos paquetes.

* nginx-ingress
* cert-manager

La tabla nginx-ingress se encuentra en el espacio de nombres de google apis https://kubernetes-charts.storage.googleapis.com/ y nos permite crear los objetos de ingreso para nuestros servicios, que define la ruta que las solicitudes deben tomar si se encuentran bajo ciertos criterios, por ejemplo, un subdominio o una ruta de dominio interna
 (eduardo.mydomain.com or mydomain.com/eduardo or * .mydomain.com).

El cuadro de cert-manager está en el repositorio de jetstack https://charts.jetstack.io, esto nos ayudará a crear un clúster de emisión de certificados, cuando la entrada de un servicio especifica que un servicio debe tener un tls, deberá definir su nombre y tipo de emisor, en este ejemplo usaremos letsencrypt, que es un esquema de certificación abierto y gratuito, pero también puede definir certificados emitidos por una entidad certificadora o algún servicio de certificación externo.

La instalación de estos repositorios se realizará dentro de otro espacio de nombres de clúster para que podamos facilitar la operación cuando tengamos una gran cantidad de servicios.

`kubectl create namespace ingress-basic`

Agregue el repositorio de Google Apis.
`helm repo add stable https://kubernetes-charts.storage.googleapis.com/`

Instalar nginx-ingress.
`helm install nginx stable/nginx-ingress --namespace ingress-basic --set controller.replicaCount=2 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux`

Valide y guarde la IP externa del controlador.

`kubectl get service -l app=nginx-ingress --namespace ingress-basic`

Otro chat que necesitamos es la Definición de recursos personalizados que le permite definir recursos personalizados.

`kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.13/deploy/manifests/00-crds.yaml`

Ahora debemos deshabilitar la validación de recursos para la entrada.
`kubectl label namespace ingress-basic cert-manager.io/disable-validation=true`


Ahora vamos a instalar el Certificate Manager Cert-Manager.

Agregamos el repositorio Jetstack.
`helm repo add jetstack https://charts.jetstack.io`

Actualizamos.
`helm repo update`

Al igual que con nginx, lo instalamos dentro del espacio de nombres básico de ingreso.
`helm install cert-manager --namespace ingress-basic --version v0.13.0 jetstack/cert-manager`

Valide que tenemos los pods instalados bajo el espacio de nombres básico de ingreso.
`kubectl get pods --namespace ingress-basic`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/22.JPG?raw=true)

Cree la zona DNS para nuestro dominio.

`az network dns zone create --name $dnsName --resource-group $groupName --zone-type public`

Obtenga las URL de NS, para configurar nuestro dominio en el sistema donde compra su dominio.

`az network dns zone show --name $dnsName --resource-group $groupName --query "nameServers"  --output tsv`

Apuntamos nuestro dominio a esos DNS.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/23.JPG?raw=true)

Agregue un conjunto de registros "A" al conjunto de registros de la Zona DNS con la IP de nuestro equilibrador.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/24.JPG?raw=true)

`az network dns record-set a add-record --resource-group $groupName --zone-name "ku2.com.mx" --record-set-name '*' --ipv4-address 52.191.81.204`

Podemos ver el área y el registro en el Portal de Azure.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/25.JPG?raw=true)

Ahora vamos a trabajar con el Administrador de certificados, primero vamos a crear un clúster emisor, esto no nos permitirá emitir certificados cuando creamos elementos de ingreso para los servicios que publicaremos en Kubernetes.

El clúster creará los certificados utilizando la autoridad de certificación LetsEncrypt.

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/26.JPG?raw=true)


La forma de crear estos elementos es la misma, creando sus definiciones en formato yaml.

Para el clúster, al estar en nuestra ruta yaml, creamos un archivo llamado clusterissuer.yaml

`New-Item -Path './clusterissuer.yaml' -ItemType File`

Con el Contenido

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

* El elemento "nombre" identifica el nombre de nuestro clúster.
* "correo electrónico" tenemos que definir nuestro correo electrónico.
* Los demás elementos los dejamos igual.

Aplicamos
`kubectl apply -f .\clusterissuer.yaml`


Ahora eliminaremos el servicio creado anteriormente para volver a crearlo con una modificación que nos permitirá mantener el tráfico solo por el ingreso.

En el servicio tuvimos que definir el tipo de servicio como.

`kubectl delete -f .\eduardo.yaml Deploymeny-Service.yaml`

En el Servicio cambiamos el tipo: LoadBalancer por tipo: ClusterIP, para que sea el siguiente:

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
    app: myimage
```
* type: ClusterIP // This will not create public ip

Aplicamos la implementación y el servicio nuevamente.

`kubectl delete -f .\eduardo.yaml Deploymeny-Service.yaml`


Ahora creamos el ingreso que no permitirá crear el certificado y dirigir el tráfico.

Creamos un archivo llamado ingreso.

`New-Item -Path './clusterissuer.yaml' -ItemType File`

Con el contenido:
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

Los elementos importantes son:

* nombre: myimage-ingress // el nombre del ingress
* cert-manager.io/cluster-issuer: letsencrypt // el nombre de nuestro cluster de emision
* Hospedadores:
* myimage.mypersonaldomain123.com // sobre que llamada se enturará el tráfico y también se especifica en el tls para la creación del dominio
* secretName: myimage-secret // el nombre del certificado en nuestro administrador de certificados
* host: myimage.mypersonaldomain123.com // también se define en las reglas
* backend:
* serviceName: myimage-service // el nombre que tiene nuestro servicio
* ruta: /(.*) // la expresión por la cual se aplica el redireccionamiento de tráfico

`kubectl apply -f .\ingress.yaml`


Validamos y esperamos que se cree el certificado
`kubectl get certificates --namespace ingress-basic`

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/27.JPG?raw=true)

Ahora podemos ingresar al navegador, abrir nuestra URL y validar el certificado

![](https://github.com/internetgdl/KubernetesAzure/blob/master/images/28.JPG?raw=true)

Con esto hemos terminado de "crear una aplicación con DotNetCore 3.1, ponerla dentro de un Docker, subirla a un ACR, Crear un clúster AKS con Kubernetes, Implementar implementaciones, Servicios. Instalar un controlador de ruta y administrador de certificados nginx Ingress con LetsEncrypt con Helm ".


Entonces, si tiene alguna pregunta, no dude en ponerse en contacto conmigo.

* Email: eduardo@eduardo.mx
* Web: [Eduardo Estrada](http://eduardo.mx "Eduardo Estrada")
* Twitter: [Twiter Eduardo Estrada](https://twitter.com/internetgdl "Twiter Eduardo Estrada")
* LinkedIn: https://www.linkedin.com/in/luis-eduardo-estrada/
* GitHub: [GitHub Eduardo Estrada](https://github.com/internetgdl "GitHub Eduardo Estrada")
* Eduardo Estrada
