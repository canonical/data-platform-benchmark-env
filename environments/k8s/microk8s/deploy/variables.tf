variable "model_name" {
    type = string
}

variable "base_image" {
    type = string
    default = "ubuntu@22.04"
}

variable "channel" {
    type = string
    default = "1.28/stable"
}

variable "hostpath_storage" {
    type = boolean
    default = true
}

variable "dns" {
    type = object({
        enable = boolean
        dns_server = string
    })
    default = {
        enable = true
        server = "8.8.8.8"
    }
}

variable "constraints" {
    type = object({
        instance_type = optional(string, "t2.large")
        spaces = optional(list(string))
    })
}
