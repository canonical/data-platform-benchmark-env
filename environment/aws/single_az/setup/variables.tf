variable "vpc" {
  type = map(object({
    name = optional(string, "test-vpc")
    region = optional(string, "us-east-1")
    az   = optional(string, "us-east-1a")
    cidr = optional(string, "10.0.0.0/23")
  }))
}

variable "private_cidr" {
  type = map(object({
    cidr_block = optional(string, "10.0.1.0/24")
    name       = optional(string, "private_cidr")
    tags       = optional(map(string), {})
  }))
}

variable "public_cidr" { 
  type = map(object({
    cidr_block = optional(string, "10.0.0.0/24")
    name       = optional(string, "public_cidr")
    tags       = optional(map(string), {})
  }))
}

variable "jumphost_type" {
  type = map(object({
    name = optional(string, "jumphost")
    vpc_name = var.vpc_name
    root_volume_size = optional(number, 100)
    tags = optional(map(string), {})
  }))
}

variable "key_name" {
  type = string
  default = "test-ssh-key"
}
