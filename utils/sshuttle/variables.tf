variable "jumphost_ip" {
    type = string
}

variable "subnet" {
    type = string
    default = "192.168.234.0/23"
}

variable "private_key_filepath" {
    type = string
}