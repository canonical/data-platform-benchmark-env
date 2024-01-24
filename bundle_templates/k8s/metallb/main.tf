terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.1"
    }
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
    external = {
      source = "hashicorp/external"
      version = ">=2.3.2"
    }
  }
}

variable "ip_list" {
  type = list(string)
}

variable "metallb_channel_name" {
  type = string
  default = "latest/edge"
}

variable "model_name" {
  type = string
}


locals {
  last_ip_value = element(var.ip_list, length(var.ip_list)-1)
}

resource "juju_application" "metallb" {

  model = var.model_name
  charm {
    name = "metallb"
    channel = var.metallb_channel_name
  }
  units = 1
  config = {
    iprange = "${var.ip_list.1}-${local.last_ip_value}"
  }

}

resource "null_resource" "juju_wait_metallb_app" {
  provisioner "local-exec" {
    command = "juju-wait --model ${var.model_name}"
  }

  depends_on = [juju_application.metallb]
}