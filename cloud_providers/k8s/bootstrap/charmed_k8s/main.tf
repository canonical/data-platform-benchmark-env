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
    external = {
      source = "hashicorp/external"
      version = ">=2.3.2"
    }
  }
}

variable cos {
  type = object({
    bundle = string
    overlay = string
    model_name = string
  })
  default = {
    bundle = "./bundle.yaml"
    overlay = "./cos-overlay.yaml"
    model_name = "cos"
  }
}

variable k8s_model {
  type = string
  default = "charmed-k8s"
}

variable cni_cidr {
  type = string
  default = "10.10.10.0/24"
}

variable service_cidr {
  type = string
  default = "10.20.20.0/24"
}

variable aux_constraints {
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

variable k8s_control_constraints {
  type = object({
    instance_type = string
    root_disk_size = string
    spaces = list(string)
  })
  default = {
    instance_type = "t2.medium"
    root_disk_size = "200G"
    spaces = ["internal-space"]
  }
}

variable k8s_control_num_units {
  type = number
  default = 3
}

variable k8s_worker_constraints {
  type = object({
    instance_type = string
    root_disk_size = string
    spaces = list(string)
  })
  default = {
    instance_type = "c6a.xlarge"
    root_disk_size = "400G"
    spaces = ["internal-space"]
  }
}

variable k8s_worker_num_units {
  type = number
  default = 3
}

variable etcd-channel {
  type = string
  default = "3.4/stable"
}

variable k8s-channel {
  type = string
  default = "1.28/stable"
}

locals {
  cos_overlay = yamldecode(file(var.cos.overlay))
}

resource "local_file" "charmed_k8s_bundle" {

  filename = "${path.module}/charmed_k8s.yaml"

  content = templatefile(
    "./charmed_k8s/bundle.yaml",
    {
      # params = var.control_bundle_params
      params = {
        ## COS offer model
        "cos_model" = var.cos.model_name
        "grafana-dashboards" = contains(var.cos.overlay, "grafana")
        "logging" = contains(var.cos.overlay, "logging")
        "prometheus-scrape" = contains(var.cos.overlay, "prometheus")
        "prometheus-receive-remote-write" = contains(var.cos.overlay, "prometheus")
        ## bundle parameters
        "cni_cidr" = var.cni_cidr
        "service_cidr" = var.service_cidr
        "etcd-channel" = var.etcd-channel
        "k8s-channel" = var.k8s-channel
        "aux-constraints" = "instance-type=${var.aux_constraints.instance_type} root-disk=${var.aux_constraints.root_disk_size} spaces=${join(" ", var.aux_constraints.spaces)}"
        "k8s-control-constraints" = "instance-type=${var.k8s_control_constraints.instance_type} root-disk=${var.k8s_control_constraints.root_disk_size} spaces=${join(" ", var.k8s_control_constraints.spaces)}"
        "k8s-control-num-units" = var.k8s_control_num_units
        "k8s-worker-constraints" = "instance-type=${var.k8s_worker_constraints.instance_type} root-disk=${var.k8s_worker_constraints.root_disk_size} spaces=${join(" ", var.k8s_worker_constraints.spaces)}"
        "k8s-worker-num-units" = var.k8s_worker_num_units
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