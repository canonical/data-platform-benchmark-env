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

## Seems it is still affected by: https://bugs.launchpad.net/juju/+bug/2039179
# resource "null_resource" "deploy_microk8s_app" {

#   # Finally, load the new microk8s as another cloud in juju
#   provisioner "local-exec" {
#     command = "juju deploy microk8s --model=${var.model_name} --channel=${var.microk8s_charm_channel} --to=${juju_machine.microk8s_vm.machine_id} --config hostpath_storage=true"
#     interpreter = ["/bin/bash", "-c"]
#   }
#   depends_on = [juju_machine.microk8s_vm]
# }
# resource "null_resource" "juju_wait_microk8s_app" {
#   provisioner "local-exec" {
#     command = "juju-wait --model ${var.model_name}"
#   }
#   depends_on = [null_resource.deploy_microk8s_app]
# }

resource "juju_application" "microk8s" {
  name = "microk8s"
  model = var.model_name
  charm {
    name = "microk8s"
    channel = var.microk8s_charm_channel
    # # Checking TF state and could not see "base"
    # base = juju_machine.microk8s_vm.base
    series = juju_machine.microk8s_vm.series
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


resource "null_resource" "juju_agents_local_build_if_needed" {
  # Check if we should compile the agent and install it locally in microk8s
  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = file(var.private_key_path)
    host = var.microk8s_ips.0
  }

  provisioner "file" {
    content = <<-EOT
    #!/bin/bash

    # If we are going to build the agent, get its path
    if [ -z "${var.juju_build_from_git_branch}" ]; then
      echo "No build_agent_branch provided, skipping agent build"
      exit 0
    fi

    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo apt update

    sudo apt install -y gcc make libsqlite3-dev musl ca-certificates bzip2 distro-info-data zip git docker-buildx-plugin docker-ce docker-ce-cli docker-ce-rootless-extras docker-compose-plugin
    sudo snap install go --channel=1.20/stable --classic

    git clone https://github.com/juju/juju -b ${var.juju_build_from_git_branch}

    pushd "juju/"
    DEBUG_JUJU=${var.juju_build_with_debug_symbols_code} make build
    sudo JUJU_BUILD_NUMBER=1 DEBUG_JUJU=${var.juju_build_with_debug_symbols_code} make microk8s-operator-update
    popd
    EOT
    destination = "/tmp/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh args",
    ]
  }
  depends_on = [null_resource.juju_wait_microk8s_app]
}

# resource "null_resource" "juju_agents_local_build_if_needed" {
#   provisioner "local-exec" {
#     command = <<-EOT
#     # If we are going to build the agent, get its path
#     if [ -z "${var.juju_build_from_git_branch}" ]; then
#       echo "No build_agent_branch provided, skipping agent build"
#       exit 0
#     fi

#     curl -fsSL https://get.docker.com -o get-docker.sh
#     sudo sh get-docker.sh
#     sudo apt update

#     sudo apt install -y git docker-buildx-plugin docker-ce docker-ce-cli docker-ce-rootless-extras docker-compose-plugin
#     sudo snap install go --channel=1.20/stable --classic

#     git clone https://github.com/juju/juju -b ${var.juju_build_from_git_branch}

#     pushd "juju/"
#     DEBUG_JUJU=${var.juju_build_with_debug_symbols_code} make build
#     DEBUG_JUJU=${var.juju_build_with_debug_symbols_code} make microk8s-operator-update
#     popd
#     EOT
#     interpreter = ["/bin/bash", "-c"]
#   }

#   depends_on = [null_resource.juju_wait_microk8s_app]
# }

resource "null_resource" "save_kubeconfig" {

  # Finally, load the new microk8s as another cloud in juju
  provisioner "local-exec" {
    command = "ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${var.microk8s_ips.0} 'sudo microk8s config' > ${pathexpand(var.microk8s_kubeconfig)}"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [null_resource.juju_agents_local_build_if_needed]
}