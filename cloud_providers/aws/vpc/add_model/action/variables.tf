// --------------------------------------------------------------------------------------
//      Contains all the common variables. Modules may define their own vars as well
// --------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------
//      Varibles that must be set
// --------------------------------------------------------------------------------------

variable "AWS_ACCESS_KEY" {
    type      = string
    sensitive = true
}

variable "AWS_SECRET_KEY" {
    type      = string
    sensitive = true
}

variable "vpc" {
  type = object({
    name   = string
    region = string
    cidr   = string
  })
  default = {
    name   = "test-vpc"
    region = "us-east-1"
    cidr   = "192.168.234.0/23"
  }
}

variable "controller_info" {
  type = object({
    name          = string
    api_endpoints = string
    ca_cert       = string
    username      = string
    password      = string
  })
}

variable "spaces" {
  type = list(object({
    name    = string
    subnets = list(string)
  }))
  default = [
    {
      name    = "public-space"
      subnets = ["192.168.234.0/24"]
    },
    {
      name    = "internal-space"
      subnets = ["192.168.235.0/24"]
    },
  ]
}

variable "provider_tags" {
  type = map(string)
  default = {
    CI = "true"
  }
}

variable "fan_networking_cidr" {
  type    = string
  default = "252.0.0.0/8"
}

variable "model_name" {
  type    = string
  default = "test"
}

variable "controller_name" {
  type    = string
  default = "aws-juju"
}

variable "vpc_id" {
  type    = string
}