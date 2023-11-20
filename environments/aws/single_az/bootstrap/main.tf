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
  controllers_map = yamldecode(file(data.local_file.controller_info.filename))["controllers"]
  accounts_map    = yamldecode(file(data.local_file.account_info.filename))["controllers"]
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
resource "null_resource" "remove_creds_file" {

  provisioner "local-exec" {
    command = "rm -rf ${path.cwd}/credentials.yaml"
  }

  depends_on = [terraform_data.add_creds]
}

resource "null_resource" "bootstrap" {

  triggers = {
    controller_name = var.controller_name
  }

  provisioner "local-exec" {
    command = "juju bootstrap aws ${var.controller_name} --credential aws_tf_creds  --model-default vpc-id=${var.vpc_id} --model-default vpc-id-force=true --config vpc-id=${var.vpc_id} --config vpc-id-force=true --constraints 'instance-type=${var.constraints.instance_type} root-disk=${var.constraints.root_disk_size}' --to subnet=${var.private_cidr}"
  }

#  provisioner "local-exec" {
#    when = destroy
#    command = "juju destroy-controller --yes --destroy-storage --destroy-all-models --force --no-wait ${self.triggers.controller_name}"
#  }

  provisioner "local-exec" {
    when = destroy
    command = "juju remove-credential aws aws_tf_creds --client"
  }

  depends_on = [null_resource.remove_creds_file]
}

data "local_file" "controller_info" {
  filename = pathexpand("~/.local/share/juju/controllers.yaml")

  depends_on = [null_resource.bootstrap]
}

data "local_file" "account_info" {
  filename = pathexpand("~/.local/share/juju/accounts.yaml")

  depends_on = [null_resource.bootstrap]
}
