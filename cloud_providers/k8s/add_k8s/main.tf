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

variable "microk8s_kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type = string
}

variable "microk8s_cloud_name" {
    description = "Name of the cloud to add"
    type = string
}

variable "controller_name" {
    description = "Name of the controller to add the k8s"
    type = string
}

resource "null_resource" "prepare_microk8s_cloud" {

  triggers = {
    cloud_name = var.microk8s_cloud_name
  }

  provisioner "local-exec" {
    command = "kubectl config --kubeconfig ${var.microk8s_kubeconfig_path} view --raw | juju add-k8s ${var.microk8s_cloud_name} --client --controller ${var.controller_name}"
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
    juju remove-credential ${self.triggers.cloud_name} ${self.triggers.cloud_name} --client;
    juju remove-cloud ${self.triggers.cloud_name} --client
    EOT
  }
}