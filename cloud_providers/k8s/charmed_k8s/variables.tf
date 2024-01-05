# Specifies the VM controller
variable "juju_controller_info" {
  type = object({
        name = string
        api_endpoints = string
        ca_cert = string
        username = string
        password = string
    })
}

# Bundle parameters:
variable "grafana-dashboards" {
    type = bool
    default = true
}
variable "logging" {
    type = bool
    default = true
}
variable "prometheus-scrape" {
    type = bool
    default = true
}
variable "prometheus-receive-remote-write" {
    type = bool
    default = true
}

variable "k8s-channel" {
    type = string
    default = "1.28/stable"
}
variable "etcd-channel" {
    type = string
    default = "3.4/stable"
}

variable "aux-constraints" {
    type = object({
        instance_type = string
        root_disk_size = string
        spaces = list(string)
    })
    default = {
        instance_type = "t2.small"
        root_disk_size = "50G"
        spaces = ["internal-space"]
    }
}

variable "k8s-worker-constraints" {
    type = object({
        instance_type = string
        root_disk_size = string
        spaces = list(string)
    })
    default = {
        instance_type = "c6a.2xlarge"
        root_disk_size = "300G"
        spaces = ["internal-space"]
    }
}

variable "k8s-control-plane-constraints" {
    type = object({
        instance_type = string
        root_disk_size = string
        spaces = list(string)
    })
    default = {
        instance_type = "c6a.large"
        root_disk_size = "300G"
        spaces = ["internal-space"]
    }
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
