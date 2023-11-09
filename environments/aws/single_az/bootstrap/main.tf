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
        aws_tf_creds = {
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
    command = "juju bootstrap aws aws-tf-controller --credential aws_tf_creds  --model-default vpc-id=${var.vpc_id} --model-default vpc-id-force=true --config vpc-id=${var.vpc_id} --config vpc-id-force=true --constraints 'instance-type=${var.constraints.instance_type} root-disk=${var.constraints.root_disk_size}' --to subnet=${var.private_cidr}"
  }

  provisioner "local-exec" {
    when = destroy
    command = "juju destroy-controller --destroy-storage --destroy-all-models --force --no-wait aws-tf-controller"
  }

  provisioner "local-exec" {
    when = destroy
    command = "juju remove-credential aws aws_tf_creds"
  }

  depends_on = [terraform_data.remove_creds_file]
}
