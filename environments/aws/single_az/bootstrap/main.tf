/*

  # It is not possible to add credentials before actually having a controller.
  terraform {
    required_version = ">= 1.5.0"
    required_providers {
      juju = {
        version = ">= 0.3.1"
        source  = "juju/juju"
      }
    }
  }

  provider "juju" {}

  resource "juju_credential" "aws_creds" {
    name = var.aws_creds_name

    cloud {
      name = "aws"
    }

    auth_type = "access-key"

    attributes = {
      auth-key   = var.AWS_ACCESS_KEY
      secret-key = var.AWS_SECRET_KEY
    }
  }
*/

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

locals {
  credential = {
    credentials = {
      aws = {
        aws_creds = {
          auth-type = "access-key"
          access-key = var.AWS_ACCESS_KEY
          secret-key = var.AWS_SECRET_KEY
        }
      }
    }
  }
}

resource "local_sensitive_file" "generate_creds_yaml" {
  content     = yamlencode(local.credential)
  filename    = "${path.cwd}/credentials.yaml"
}

resource "terraform_data" "add_creds" {

  provisioner "local-exec" {
    command = "juju add-credential aws -f ${path.cwd}/credentials.yaml --client"
  }

  depends_on = [local_sensitive_file.generate_creds_yaml]
}

// Cleaning up the credentials file
resource "terraform_data" "remove_creds_file" {

  provisioner "local-exec" {
    command = "rm -rf ${path.cwd}/credentials.yaml"
  }

  depends_on = [terraform_data.add_creds]
}

resource "terraform_data" "bootstrap" {

  provisioner "local-exec" {
    command = "juju bootstrap aws --credential aws_creds  --model-default vpc-id=${var.vpc_id} --model-default vpc-id-force=true --config vpc-id=${var.vpc_id} --config vpc-id-force=true --constraints 'instance-type=${var.constraints.instance_type} root-disk=${var.constraints.root_disk_size}' --to subnet=${var.private_cidr}"
  }

#  depends_on = [juju_credential.aws_creds]
  depends_on = [terraform_data.remove_creds_file]
}
