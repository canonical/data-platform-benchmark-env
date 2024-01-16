variable "vpc" {
  type = object({
    name   = string
    region = string
    az     = string
    cidr   = string
  })
  default = {
    name   = "test-vpc"
    region = "us-east-1"
    az     = "us-east-1a"
    cidr   = "192.168.234.0/23"
  }
}

variable "AWS_ACCESS_KEY" {
    type      = string
    sensitive = true
}

variable "AWS_SECRET_KEY" {
    type      = string
    sensitive = true
}

variable "private_cidr" {
  type = object({
    cidr       = string
    name       = string
    tags       = map(string)
  })
  default = {
    cidr = "192.168.235.0/24"
    name = "private_cidr"
    tags = {}
  }
}

variable "public_cidr" {
  type = object({
    cidr       = string
    name       = string
    tags       = map(string)
  })
  default = {
    cidr = "192.168.234.0/24"
    name = "public_cidr"
    tags = {}
  }
}


variable "jumphost_type" {
  type = object({
    name             = string
    root_volume_size = number
    tags             = map(string)
  })
  default = {
    name             = "jumphost"
    root_volume_size = 100
    tags             = {}
  }
}

variable "key_name" {
  type    = string
  default = "test-ssh-key"
}

variable "microk8s_sg" {
  type    = string
  default = "microk8s_sg"
}
