variable "model_name" {
    type = string
}

variable "constraints" {
    type = object({
      instance_type = string
      spaces = string
      root-disk = string
      data-disk = string
      channel = string
    })
}

variable "node_count" {
    type = number
    default = 3
}

variable "base" {
    type = string
    default = "ubuntu@22.04"
}

variable "channel" {
    type = string
    default = "2/edge"
}

variable "tls-operator-integration" {
    type = string
}

variable grafana-dashboard-integration {
  type = string
}

variable "logging-integration" {
    type = string
}

variable "prometheus-scrape-integration" {
    type = string
}

variable "prometheus-receive-remote-write-integration" {
    type = string
}

variable "expose" {
    type = bool
    default = false
}