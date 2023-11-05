terraform {
  required_version = "~> 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.4"
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
