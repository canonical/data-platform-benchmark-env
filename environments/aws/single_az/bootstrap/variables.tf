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