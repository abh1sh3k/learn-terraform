output "public_ip" {
  description = "Public IP of VM"
  value = azurerm_public_ip.publicip.ip_address
}

output "sub_domain" {
  value = "${var.CUSTOMER_NAME}.${data.azurerm_dns_zone.dns_zone.name}"
}
