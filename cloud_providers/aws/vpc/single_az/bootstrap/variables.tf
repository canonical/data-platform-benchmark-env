variable "aws_creds_name" {
    type    = string
    default = "aws_creds"
}

variable "vpc_id" {
    type = string
}

variable "AWS_ACCESS_KEY" {
    type = string
    sensitive = true
}

variable "AWS_SECRET_KEY" {
    type = string
    sensitive = true
}

variable "private_cidr" {
    type = string
}

variable "controller_name" {
    type = string
    default = "aws-tf-controller"
}

variable "fan_networking_cidr" {
    type = string
    default = "252.0.0.0/8"
}

variable "constraints" {
    type = object({
        instance_type  = string
        root_disk_size = string
    })
    default = {
        instance_type  = "t2.medium"
        root_disk_size = "100G"
    }
}

variable "agent_version" {
    type = string
    default = ""
}

variable "build_agent_path" {
    type = string
    default = ""
}

variable "build_with_debug_symbols" {
    type = bool
    default = true
}