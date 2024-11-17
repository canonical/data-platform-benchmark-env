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
    cidr   = "192.168.240.0/22"
  }
}

variable "private_cidrs" {
  type = map(object({
    cidr = string
    name = string
    az = string
  }))
  default = {
    private_cidr1 = {
      cidr = "192.168.241.0/24"
      name = "private_cidr1"
      az = "us-east-1a"
    }
  }
}

variable "public_cidr" {
  type = object({
    cidr = string
    name = string
    az = string
  })
  default = {
    cidr = "192.168.240.0/24"
    name = "public_cidr"
    az = "us-east-1a"
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
  default = "test"
}

variable "provider_tags" {
  type = map(string)
  default = {
    CI = "true"
  }
}
