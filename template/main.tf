terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.46.0"
    }
  }
  backend "azurerm" {
    resource_group_name = "storage_rg"
    storage_account_name = "storage_name"
    container_name = "storage_container_name"
    key = "storage_key"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  skip_provider_registration = true
}

module "vm" {
    source = "../../modules/vm"
    CUSTOMER_NAME = "vm_customer_name"
    vm_size = "customer_vm_size"
}

output "public_ip" {
  value = module.vm.public_ip
}

output "sub-domain" {
  value = module.vm.sub_domain
}
