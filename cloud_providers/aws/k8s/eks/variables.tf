variable "node_groups" {
    type = map(object({
        name = string
        instance_types = list(string)
        min_size = number
        max_size = number
        desired_size = number
    }))
    default = {
        "group1" = {
            name = "group1"
            instance_types = ["t3.medium"]
            min_size = 1
            max_size = 5
            desired_size = 3
        }
    }
}

variable cluster_version {
    type = string
    default = "1.27"
}

variable eks_public_access {
    type = bool
    default = false
}

variable vpc_id {
    type = string
}

variable vpc_private_subnets {
    type = list(string)
}