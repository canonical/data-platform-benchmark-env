terraform {
  required_version = ">= 1.5.0"
  required_providers {
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
  }
}

provider juju {
  controller_addresses = var.controller_info.api_endpoints
  username = var.controller_info.username
  password = var.controller_info.password
  ca_certificate = var.controller_info.ca_cert
}

resource "juju_model" "new_model" {
  name = var.name

  cloud {
    name   = "aws"
    region = var.region
  }

  config = {
    logging-config              = "<root>=INFO"
    development                 = true
    vpc-id                      = var.vpc_id
    vpc-id-force                = true
    update-status-hook-interval = "1m"
  }
}

data "local_file" "pub_key" {
  filename = pathexpand("~/.local/share/juju/ssh/juju_id_rsa.pub")

}


resource "juju_ssh_key" "add_key" {
  model   = var.name
  payload = data.local_file.juju_pub_key.content

  depends_on = [resource.juju_model.new_model]
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
