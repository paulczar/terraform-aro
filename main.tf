terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "=3.0.1"
    }
    azureopenshift = {
      source  = "rh-mobb/azureopenshift"
      version = "~> 0.0.1"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.15.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider azureopenshift {
}

provider "azuread" {
  # tenant_id = "00000000-0000-0000-0000-000000000000"
}

locals {
  resource_prefix = coalesce(var.resource_group_name, "aro-${var.cluster_name}-${var.location}")
}

resource "azurerm_resource_group" "aro" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
}


