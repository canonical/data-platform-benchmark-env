variable "name" {
    type = string
}

variable "vpc_id" {
    type = string
}

variable "subnets" {
    type = list(string)
}