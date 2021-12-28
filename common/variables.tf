variable "RESOURCE_GROUP_NAME" {
}

variable "RESOURCE_LOCATION" {
    default = "East US"
}

variable "sg_ports" {
    description = "list of ingress ports"
    default     =  {
        "100" : "443",
        "110" : "8443",
        "120" : "9999",
        "130" : "9998",
        "140" : "8081",
        "150" : "22",
        "160" : "15672",
        "170" : "11003"
    }
}