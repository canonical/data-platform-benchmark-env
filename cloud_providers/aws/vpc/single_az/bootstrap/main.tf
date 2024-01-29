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

locals {
  credential = {
    credentials = {
      aws = {
        aws_tf_creds = {
          auth-type = "access-key"
          access-key = var.AWS_ACCESS_KEY
          secret-key = var.AWS_SECRET_KEY
        }
      }
    }
  }
  juju_version = var.agent_version != ""   ? " --agent-version=${var.agent_version}" : "" 
  build_agent  = var.build_agent   == true ? " --build-agent=${var.build_agent}"     : "" 
}

resource "local_sensitive_file" "generate_creds_yaml" {
  content     = yamlencode(local.credential)
  filename    = "${path.cwd}/credentials.yaml"
}

resource "terraform_data" "manage_creds" {

  provisioner "local-exec" {
    command = "juju add-credential aws -f ${path.cwd}/credentials.yaml --client"
  }

  provisioner "local-exec" {
    when = destroy
    command = "juju remove-credential aws aws_tf_creds --client"
  }
  depends_on = [local_sensitive_file.generate_creds_yaml]
}

// Cleaning up the credentials file
resource "null_resource" "remove_creds_file" {

  provisioner "local-exec" {
    command = "rm -rf ${path.cwd}/credentials.yaml"
  }

  depends_on = [terraform_data.manage_creds]
}

resource "null_resource" "bootstrap" {

  triggers = {
    controller_name = var.controller_name
  }

  # Remove the fan-networking from model-config by setting container-networking-method=local
  provisioner "local-exec" {
    command = "juju bootstrap aws ${var.controller_name} --credential aws_tf_creds --model-default fan-config=${var.private_cidr}=${var.fan_networking_cidr} --model-default container-networking-method=local --config vpc-id=${var.vpc_id} --config vpc-id-force=true --config container-networking-method=fan --constraints 'instance-type=${var.constraints.instance_type} root-disk=${var.constraints.root_disk_size}' --to subnet=${var.private_cidr} ${local.juju_version} ${local.build_agent}"
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
    juju destroy-controller --no-prompt --destroy-storage --destroy-all-models --force --no-wait ${self.triggers.controller_name} --model-timeout=1200s;
    juju remove-credential aws aws_tf_creds --client
    EOT
  }

  depends_on = [null_resource.remove_creds_file]
}

resource "local_file" "controller_info" {
  filename = pathexpand("/tmp/juju_show_controller.sh")
  content = <<-EOT
  #!/bin/bash
  jq -n --arg ctl "$(juju show-controller --show-password)" '{"output": $ctl}'
  EOT
  file_permission = "0700"
  depends_on = [null_resource.bootstrap]
}

data "external" "juju_controller_info" {
  program = ["bash", local_file.controller_info.filename]
  depends_on = [local_file.controller_info]
}

locals {
  juju_endpoints = join(",", yamldecode(data.external.juju_controller_info.result["output"])[var.controller_name]["details"]["api-endpoints"])
}

# Removes any fan-network-method
data "external" "controller_api_endpoints_without_fan_networking" {
  program = ["python3", "-c", "import ipaddress; print( '{ \"output\": \"' + ','.join([ip for ip in '${local.juju_endpoints}'.split(',') if ipaddress.IPv4Address(ip.split(':')[0]) not in ipaddress.IPv4Network('${var.fan_networking_cidr}')]) + '\" }' );"]
}