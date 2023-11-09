variable "name" {
    type = string
}

variable "region" {
    type = string
}

variable "vpc_id" {
    type = string
}

variable "spaces" {
  type = list(object({
    name = string
    subnets = list(string)
  }))
  default = [
    { 
      name = "public-space"
      subnets = ["192.168.234.0/24"]
    },
    {
      name = "internal-space"
      subnets = ["192.168.235.0/24"]
    },
  ]
}
