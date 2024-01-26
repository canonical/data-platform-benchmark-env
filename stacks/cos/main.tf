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
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
  }
}

variable "cos_bundle" {
  type = string
  default = "./bundle.yaml"
}

variable "cos_overlay" {
  type = string
  default = "./cos-overlay.yaml"
}

variable "cos_model_name" {
  type = string
}

# Unfortunately, deploying entire bundles with overlay is not yet available
resource "null_resource" "deploy_cos_bundle" {
  provisioner "local-exec" {
    command = <<-EOT
    juju deploy ${var.cos_bundle} --model ${var.cos_model_name} --overlay ${var.cos_overlay} --trust;
    juju-wait --model ${var.cos_model_name}
    EOT
  }
}

# Reloading the COS model so we can have a proper destroy-time provisioner
resource "terraform_data" "cos" {
  input = var.cos_model_name

  provisioner "local-exec" { 
    when = destroy
    command = "juju destroy-model --force --no-wait --no-prompt --destroy-storage ${self.input}"
    on_failure = continue # If the model has been successfully destroyed, then we continue
  }

  depends_on = [null_resource.deploy_cos_bundle]

}

output "cos_model_name" {
  value = "${var.cos_model_name}"
}

output "cos_bundle_filepath" {
  value = "${var.cos_bundle}"
}

output "cos_overlay_filepath" {
  value = "${var.cos_overlay}"
}