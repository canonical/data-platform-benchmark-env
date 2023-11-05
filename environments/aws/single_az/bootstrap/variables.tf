variable "aws_creds" {
  type = optional(string, "aws_creds")
}

variable "vpc_id" {
    type = string
}

variable "access_key" {
    type = map(object({
        auth_key   = string
        secret_key = string
    }))
}

variable "private_cidr" {
  type = string
}

variable "constraints" {
    type = map(object({
        instance_type  = optional(string, "t2.medium")
        root_disk_size = optional(string, "100G")
    }))
}