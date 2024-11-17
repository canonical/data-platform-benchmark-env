terraform {
  required_version = ">= 1.5.0"
  required_providers {
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }
}

resource "juju_model" "new_model" {
  name = var.model_name

  cloud {
    name   = "aws"
    region = var.region
  }

  config = {
    container-networking-method = "fan"
    logging-config              = "<root>=DEBUG"
    development                 = true
    vpc-id                      = var.vpc_id
    vpc-id-force                = true
    update-status-hook-interval = "5m"
  }

  #  provisioner "local-exec" {
  #    when = destroy
  #    command = <<-EOT
  #    juju destroy-model --force --no-wait --no-prompt --destroy-storage ${self.name}
  #    EOT
  #  }
}

resource "terraform_data" "add_space" {
  for_each = {
    for index, space in var.spaces :
    space.name => space
  }

  provisioner "local-exec" {
    command = "juju add-space --model ${var.model_name} ${each.key} ${join(" ", each.value.subnets)}"
  }

  depends_on = [resource.juju_model.new_model]
}


output "name" {
  description = "model name"
  value       = var.model_name
}