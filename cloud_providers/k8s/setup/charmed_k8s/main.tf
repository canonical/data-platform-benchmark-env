terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
    external = {
      source  = "hashicorp/external"
      version = ">=2.3.2"
    }
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
  }
}

variable "cos" {
  type = object({
    bundle     = string
    overlay    = string
    model_name = string
  })
  default = {
    bundle     = "./bundle.yaml"
    overlay    = "./cos-overlay.yaml"
    model_name = "cos"
  }
}

variable "k8s_model" {
  type    = string
  default = "charmed-k8s"
}

variable "cni_cidr" {
  type    = string
  default = "10.10.10.0/24"
}

variable "service_cidr" {
  type    = string
  default = "10.20.20.0/24"
}

variable "aux_constraints" {
  type = object({
    instance_type  = string
    root_disk_size = string
    spaces         = list(string)
  })
  default = {
    instance_type  = "t2.small"
    root_disk_size = "50G"
    spaces         = ["internal-space"]
  }
}

variable "k8s_control_constraints" {
  type = object({
    instance_type  = string
    root_disk_size = string
    spaces         = list(string)
  })
  default = {
    instance_type  = "t2.medium"
    root_disk_size = "200G"
    spaces         = ["internal-space"]
  }
}

variable "k8s_control_num_units" {
  type    = number
  default = 3
}

variable "k8s_worker_constraints" {
  type = object({
    instance_type  = string
    root_disk_size = string
    spaces         = list(string)
  })
  default = {
    instance_type  = "c6a.xlarge"
    root_disk_size = "400G"
    spaces         = ["internal-space"]
  }
}

variable "k8s_worker_num_units" {
  type    = number
  default = 3
}

variable "etcd-channel" {
  type    = string
  default = "3.4/stable"
}

variable "k8s-channel" {
  type    = string
  default = "1.28/stable"
}

locals {
  cos_overlay                 = yamldecode(file(var.cos.overlay))
  cos_overlay_keys            = keys(local.cos_overlay["applications"])
  cos_overlay_prom_offer_keys = keys(local.cos_overlay["applications"]["prometheus"]["offers"])
}

resource "local_file" "charmed_k8s_bundle" {

  filename = "${path.cwd}/charmed_k8s.yaml"

  content = templatefile(
    "${path.module}/bundle.yaml",
    {
      # params = var.control_bundle_params
      params = {
        ## COS offer model
        "cos_model"                       = var.cos.model_name
        "grafana_dashboards"              = contains(local.cos_overlay_keys, "grafana")
        "logging"                         = contains(local.cos_overlay_keys, "logging")
        "prometheus-scrape"               = contains(local.cos_overlay_prom_offer_keys, "prometheus-scrape")
        "prometheus-receive-remote-write" = contains(local.cos_overlay_prom_offer_keys, "prometheus-receive-remote-write")
        ## bundle parameters
        "cni_cidr"                = var.cni_cidr
        "service_cidr"            = var.service_cidr
        "etcd-channel"            = var.etcd-channel
        "k8s-channel"             = var.k8s-channel
        "aux-constraints"         = "instance-type=${var.aux_constraints.instance_type} root-disk=${var.aux_constraints.root_disk_size} spaces=${join(" ", var.aux_constraints.spaces)}"
        "k8s-control-constraints" = "instance-type=${var.k8s_control_constraints.instance_type} root-disk=${var.k8s_control_constraints.root_disk_size} spaces=${join(" ", var.k8s_control_constraints.spaces)}"
        "k8s-control-num-units"   = var.k8s_control_num_units
        "k8s-worker-constraints"  = "instance-type=${var.k8s_worker_constraints.instance_type} root-disk=${var.k8s_worker_constraints.root_disk_size} spaces=${join(" ", var.k8s_worker_constraints.spaces)}"
        "k8s-worker-num-units"    = var.k8s_worker_num_units
      }
    }
  )
}

resource "null_resource" "charmed_k8s_deploy" {

  provisioner "local-exec" {
    command = "juju deploy --model ${var.k8s_model} ${local_file.charmed_k8s_bundle.filename}"
  }

  depends_on = [local_file.charmed_k8s_bundle]
}

output "charmed_k8s_config" {
  value = "juju config kubernetes-master"
}