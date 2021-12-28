# Resource group name
output "rg_name" {
  value = data.azurerm_resource_group.rg.name
}

# Virtual Network Outputs
## Virtual Network Name
output "virtual_network_name" {
  description = "Virtual Network Name"
  value = azurerm_virtual_network.vnet.name
}

## Subnet Name 
output "subnet_name" {
  description = "Subnet Name"
  value = azurerm_subnet.subnet.name
}

# Network Security Outputs
## Web Subnet NSG Name 
output "subnet_nsg_name" {
  description = "Subnet NSG Name"
  value = azurerm_network_security_group.subnet_nsg.name
}