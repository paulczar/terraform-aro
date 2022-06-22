# Create Virtual Network for ARO cluster
resource "azurerm_virtual_network" "aro" {
  name                = "${local.resource_prefix}-vnet"
  resource_group_name = azurerm_resource_group.aro.name
  location            = azurerm_resource_group.aro.location
  address_space       = [var.aro_virtual_network_cidr_block]
}

# Create Subnet for ARO control plane
resource "azurerm_subnet" "aro-control" {
  name                 = "${local.resource_prefix}-control-subnet"
  resource_group_name  = azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = [var.aro_control_subnet_cidr_block]
  service_endpoints    = ["Microsoft.ContainerRegistry"]
  enforce_private_link_service_network_policies = false
}

# Create Subnet for ARO machine nodes
resource "azurerm_subnet" "aro-machine" {
  name                 = "${local.resource_prefix}-machine-subnet"
  resource_group_name  = azurerm_resource_group.aro.name
  virtual_network_name = azurerm_virtual_network.aro.name
  address_prefixes     = [var.aro_machine_subnet_cidr_block]
  service_endpoints    = ["Microsoft.ContainerRegistry"]
}


# Fetch details about the Azure subscription we're using
data "azurerm_subscription" "aro" {
}

# Fetch the azure ad client config so we can set the owner of the service principal
data "azuread_client_config" "current" {}

# Fetch the azure service principal for the ARO Resource Provider
data "azuread_service_principal" "aro-rp" {
  display_name = "Azure Red Hat OpenShift RP"
}

# Find the Contributor role ID for the Azure subscription
data "azurerm_role_definition" "subscription-contrib" {
  name  = "Contributor"
  scope = data.azurerm_subscription.aro.id
}

# Create an Azure AD Application for the ARO Cluster
resource "azuread_application" "aro" {
  display_name = "${local.resource_prefix}-ad-app"
  owners       = [data.azuread_client_config.current.object_id]
}

# Create an Azure Service Principal for the ARO Cluster
resource "azuread_service_principal" "aro" {
  application_id               = azuread_application.aro.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

# Create an Azure AD Service Principal password for the ARO Cluster
resource "azuread_service_principal_password" "aro" {
  service_principal_id = azuread_service_principal.aro.object_id
}

# Assign the Subscription Contributor role to the ARO resource provider Service Principal
resource "azurerm_role_assignment" "aro-rp" {
  scope                = azurerm_virtual_network.aro.id   #data.azurerm_subscription.aro.id
  # role_definition_name = "Contributor"
  principal_id         = data.azuread_service_principal.aro-rp.object_id
  role_definition_id   = data.azurerm_role_definition.subscription-contrib.id
  # principal_id         = azuread_service_principal.aro.object_id
  # app_role_id         = data.azurerm_role_definition.subscription-contrib.id
  # principal_object_id = azuread_service_principal.aro.object_id
}

# Assign the Subscription Contributor role to the Azure AD Service Principal
resource "azurerm_role_assignment" "aro-sp" {
  scope                = azurerm_resource_group.aro.id
  # role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.aro.object_id
  role_definition_id   = data.azurerm_role_definition.subscription-contrib.id
  # role_definition_id   = data.azuread_service_principal.aro-rp.object_id
  # principal_id         = azuread_service_principal.aro.object_id
  # app_role_id         = data.azurerm_role_definition.subscription-contrib.id
  # principal_object_id = azuread_service_principal.aro.object_id
}

# Create the cluster!
resource "azureopenshift_redhatopenshift_cluster" "aro" {
  name                = local.resource_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.aro.name

  master_profile {
    subnet_id = azurerm_subnet.aro-control.id
  }

  worker_profile {
    subnet_id = azurerm_subnet.aro-machine.id
  }

  service_principal {
    client_id     = azuread_service_principal.aro.object_id
    client_secret = azuread_service_principal_password.aro.value
  }

  depends_on = [
       azurerm_role_assignment.aro-sp,
       azurerm_role_assignment.aro-rp

  ]
}
