data "azurerm_resource_group" "rg" {
  name = var.RESOURCE_GROUP_NAME
}

data "azurerm_shared_image" "heal" {
  name                = var.IMAGE_NAME
  gallery_name        = var.IMAGE_GALLERY_NAME
  resource_group_name = data.azurerm_resource_group.rg.name
}

#Create Public IP Address
resource "azurerm_public_ip" "publicip" {
  name = "${var.CUSTOMER_NAME}-public-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  allocation_method = "Static"
  sku = "Standard"
  domain_name_label = "${var.CUSTOMER_NAME}-vm"
}

data "azurerm_subnet" "subnet" {
  name                 = "heal-internal"
  virtual_network_name = "${data.azurerm_resource_group.rg.name}-vnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.CUSTOMER_NAME}-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.CUSTOMER_NAME}-ip"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

data "azurerm_network_security_group" "nsg" {
  name = "Heal-nsg"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_network_interface_security_group_association" "vmnic_nsg_associate" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = data.azurerm_network_security_group.nsg.id
}

# Resource: Azure Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "linuxvm" {
  name = "${var.CUSTOMER_NAME}-xyz-vm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  size = var.vm_size
  admin_username = "testuser"
  network_interface_ids = [ azurerm_network_interface.nic.id ]
  admin_ssh_key {
    username = "testuser"
    public_key = file("${path.module}/ssh-keys/xyz.pub")
  }
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = data.azurerm_shared_image.heal.id  

  provisioner "local-exec" {
    command = <<-EOT
      sed -e s/private_ip/${azurerm_network_interface.nic.private_ip_address}/g ${path.module}/scripts/initscript.sh > initscript.sh
      sed -e s/public_ip/${azurerm_public_ip.publicip.ip_address}/g initscript.sh > initxyz.sh
      sed -e s/customer_name/${var.CUSTOMER_NAME}/ initxyz.sh > initxyz1.sh
      rm -rf initscript.sh initxyz.sh
      sed -e s/customername/${var.CUSTOMER_NAME}/ ${path.module}/scripts/generateCert.sh > generateCertificate.sh
    EOT
  }

  connection {
    host = "${azurerm_public_ip.publicip.fqdn}"
    user = "healtech"
    type = "ssh"
    private_key = "${file("/Users/abhishek/office/workspace/terraform/azurevm/testing_ssh_key/xyz")}"
    timeout = "20m"
    agent = true
  }

  provisioner "file" {
    source = "initxyz1.sh"
    destination = "/tmp/initxyz1.sh"
  }

  provisioner "file" {
    source = "generateCertificate.sh"
    destination = "/tmp/generateCertificate.sh"
  }

  provisioner "file" {
    source = "${path.module}/certs/"
    destination = "/tmp"
  }

  provisioner "file" {
    source = "${path.module}/file-template/keycloak_details.json.tpl"
    destination = "/tmp/keycloak_details.json.tpl"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/*.sh",
      "rm -f /opt/XYZ_Service/data/cert/cacerts && mv /tmp/cacerts /opt/XYZ_Service/data/cert/",
      "cd /tmp && sudo bash generateCertificate.sh",
      "cd /tmp && sudo bash initxyz1.sh"
    ]
  }
}

data "azurerm_dns_zone" "dns_zone" {
  name = var.DNS_ZONE
}

resource "azurerm_dns_a_record" "dns_record" {
  depends_on = [ azurerm_linux_virtual_machine.linuxvm ]
  name                = var.CUSTOMER_NAME
  zone_name           = data.azurerm_dns_zone.dns_zone.name
  resource_group_name = data.azurerm_dns_zone.dns_zone.resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.publicip.id
}
