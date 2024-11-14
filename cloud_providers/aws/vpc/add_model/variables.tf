variable "model_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
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
