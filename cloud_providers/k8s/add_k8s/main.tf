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
  }
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "microk8s_cloud_name" {
  description = "Name of the cloud to add"
  type        = string
}

variable "controller_name" {
  description = "Name of the controller to add the k8s"
  type        = string
}

variable "microk8s_host_details" {
  type = object({
    ip               = string
    private_key_path = string
  })
  default = {
    ip               = ""
    private_key_path = ""
  }
}

variable "charmed_k8s_host_details" {
  type = object({
    machine_id = number
    model_name = string
  })
  default = {
    machine_id = -1
    model_name = ""
  }
}

///////////////////////////////////////////////////////////////////////
/////     Retrieve the kubeconfig.
/////     If we know the type of k8s, then we can retrieve it
/////     Otherwise, just use the kubeconfig_path
///////////////////////////////////////////////////////////////////////
resource "null_resource" "microk8s_save_kubeconfig" {
  triggers = {
    ip               = var.microk8s_host_details.ip
    private_key_path = var.microk8s_host_details.private_key_path
  }

  # Finally, load the new microk8s as another cloud in juju
  provisioner "local-exec" {
    command     = <<-EOT
    if [[ -n "${self.triggers.ip}" && -n "${self.triggers.private_key_path}" ]]; then
      ssh -i ${self.triggers.private_key_path} -o StrictHostKeyChecking=no ubuntu@${self.triggers.ip} 'sudo microk8s config' > ${pathexpand(var.kubeconfig_path)}
    else
      echo "No microk8s host details provided. Using the kubeconfig_path or charmed k8s instead"
    fi
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "charmed_k8s_save_kubeconfig" {
  triggers = {
    machine_id = var.charmed_k8s_host_details.machine_id
    model_name = var.charmed_k8s_host_details.model_name
  }

  # Finally, load the new microk8s as another cloud in juju
  provisioner "local-exec" {
    command     = <<-EOT
    if [[ ${self.triggers.machine_id} -ge 0 && -n "${self.triggers.model_name}" ]]; then
      juju ssh ${self.triggers.machine_id} --model ${self.triggers.model_name} 'sudo cat /root/kubeconfig' > ${pathexpand(var.kubeconfig_path)}
    else
      echo "No charmed k8s host details provided. Using the kubeconfig_path or microk8s instead"
    fi
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
///////////////////////////////////////////////////////////////////////

resource "null_resource" "prepare_microk8s_cloud" {

  triggers = {
    cloud_name = var.microk8s_cloud_name
  }

  provisioner "local-exec" {
    command     = "kubectl config --kubeconfig ${var.kubeconfig_path} view --raw | juju add-k8s ${var.microk8s_cloud_name} --client --controller ${var.controller_name}"
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
    juju remove-credential ${self.triggers.cloud_name} ${self.triggers.cloud_name} --client;
    juju remove-cloud ${self.triggers.cloud_name} --client
    EOT
  }

  depends_on = [null_resource.microk8s_save_kubeconfig, null_resource.charmed_k8s_save_kubeconfig]
}

output "kubeconfig_path" {
  value = var.kubeconfig_path
}