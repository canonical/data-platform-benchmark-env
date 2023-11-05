terraform {
  required_version = "~> 1.5.0"
  required_providers {
    juju = {
      source  = "juju"
      version = ">= 5.0.0"
    }
  }
}

resource "juju_model" "aws_model" {
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

resource "terraform_data" "add_space" {
  provisioner "local-exec" {
    dynamic "space" {
      for_each = var.spaces
      command = "juju add-space space.name ${join(" ", space.subnets)}"
    }
  }
}