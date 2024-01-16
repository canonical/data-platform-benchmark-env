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

# For some reason, this file is getting deleted at destroy time.
resource "local_file" "id_rsa_pub_key"  {
  filename = "/tmp/id_rsa_temp123.pub"
  content  = file(pathexpand(var.public_key_path))
}

resource "juju_machine" "microk8s_vm" {
  model = var.model_name
  private_key_file = var.private_key_path
  public_key_file = local_file.id_rsa_pub_key.filename

  ssh_address = "ubuntu@${var.microk8s_ips.0}"

}

resource "juju_application" "microk8s" {
  name = "microk8s"
  model = var.model_name
  charm {
    name = "microk8s"
    channel = var.microk8s_charm_channel
  }
  units = 1
  placement = "${juju_machine.microk8s_vm.machine_id}"

  config = {
    hostpath_storage = var.hostpath_storage_enabled
  }

  depends_on = [juju_machine.microk8s_vm]
}

resource "null_resource" "juju_wait_microk8s_app" {
  provisioner "local-exec" {
    command = "juju-wait --model ${var.model_name}"
  }
  depends_on = [juju_application.microk8s]

}

resource "null_resource" "save_kubeconfig" {

  # Finally, load the new microk8s as another cloud in juju
  provisioner "local-exec" {
    command = "ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${var.microk8s_ips.0} 'sudo microk8s config' > ${pathexpand(var.microk8s_kubeconfig)}"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [null_resource.juju_wait_microk8s_app]
}