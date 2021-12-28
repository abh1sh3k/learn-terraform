variable "CUSTOMER_NAME" {
    default = "Heal"
}
variable "RESOURCE_GROUP_NAME" {
    default = "HealTech_Resource"
}

variable "STORAGE_NAME" {
    default = "heal"
}

variable "DNS_ZONE" {
    default = "saas.healsoftware.ai"
}

variable "vm_size" {
    default = "Standard_DS1_v2"
}

variable "IMAGE_NAME" {
  default = "heal_image_mid_oct"
}

variable "IMAGE_GALLERY_NAME" {
  default = "Heal"
}