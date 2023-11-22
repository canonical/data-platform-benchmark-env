terraform {
  required_version = ">= 1.5.0"
  required_providers {
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.1"
    }
  }
}

/*
provider "juju" {
  controller_addresses = var.controller_info.api_endpoints
  username = var.controller_info.username
  password = var.controller_info.password
  ca_certificate = var.controller_info.ca_cert
}
*/

resource "juju_model" "new_model" {
  name = var.name

  cloud {
    name   = "aws"
    region = var.region
  }

  config = {
    container-networking-method = "local"
    logging-config              = "<root>=INFO"
    development                 = true
    vpc-id                      = var.vpc_id
    vpc-id-force                = true
    update-status-hook-interval = "1m"
  }
}

data "local_file" "pub_key" {
  filename = pathexpand("~/.ssh/id_rsa.pub")
}

#locals {
#  ssh_key = join(" ", ["ssh-rsa", element(split(" ", data.local_file.pub_key.content), 1)])
#}

resource "juju_ssh_key" "add_key" {
  model   = var.name
  payload = data.local_file.pub_key.content
#  payload = local.ssh_key

  depends_on = [resource.juju_model.new_model]

#  # Seems that the juju_ssh_key resource does not support the destroy lifecycle
#  provisioner "local-exec" {
#    when = destroy
#    command = "juju remove-ssh-key --model ${self.model} ${self.payload}"
#  }

}

resource "terraform_data" "add_space" {
  for_each = {
    for index, space in var.spaces:
    space.name => space
  }

  provisioner "local-exec" {
    command = "juju add-space --model ${var.name} ${each.key} ${join(" ", each.value.subnets)}"
  }

  depends_on = [resource.juju_ssh_key.add_key]
}

/*
## NON JUJU TF PROVIDER, using only local-exec

locals {
  model_config = {
    logging-config              = "<root>=INFO"
    development                 = true
    vpc-id                      = var.vpc_id
    vpc-id-force                = true
    update-status-hook-interval = "1m"
  }
}

resource "local_sensitive_file" "generate_model_config_yaml" {
  content     = yamlencode(local.model_config)
  filename    = "${path.cwd}/model-config.yaml"
}

resource "terraform_data" "add_model_with_spaces" {
  for_each = {
    for index, space in var.spaces:
    space.name => space
  }

  provisioner "local-exec" {
    command = "juju add-model ${var.name} aws --config ${local_sensitive_file.generate_model_config_yaml.filename}"
  }

  provisioner "local-exec" {
    command = "juju add-space --model ${var.name} ${each.key} ${join(" ", each.value.subnets)}"
  }
}
*/