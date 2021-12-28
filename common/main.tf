terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.46.0"
    }
  }

  backend "azurerm" {
    resource_group_name = "Dummy_Resource"
    storage_account_name = "dummy_account"
    container_name = "common-tfstatefiles"
    key = "common-terraform.tfstate"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  skip_provider_registration = true
}

data "azurerm_resource_group" "rg" {
  name = var.RESOURCE_GROUP_NAME
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.RESOURCE_GROUP_NAME}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "heal-internal"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

# Create network security group
resource "azurerm_network_security_group" "subnet_nsg" {
  name                = "Heal-nsg"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
}

# Associate NSG and subnet
resource "azurerm_subnet_network_security_group_association" "subnet_nsg_associate" {
  depends_on = [ azurerm_network_security_rule.nsg_rule_inbound ]
  subnet_id = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.subnet_nsg.id
}

resource "azurerm_network_security_rule" "nsg_rule_inbound" {
  for_each = var.sg_ports
  name                       = "port-${each.value}"
  priority                   = each.key
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = each.value 
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  resource_group_name = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.subnet_nsg.name
}