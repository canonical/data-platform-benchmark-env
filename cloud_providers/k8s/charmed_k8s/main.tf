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

resource "local_file" "charmed_k8s_bundle" {

  filename = "${path.module}/control_bundle.yaml"

  content = templatefile(
    "${path.module}/../../deploy/charmed_k8s/bundle.yaml",
    {
      # params = var.control_bundle_params
      params = {
        mysql-charm            = "mysql"
        mysql-channel-entry    = "8.0/edge"
        mysql-benchmark-charm  = "mysql"
        mysql-benchmark-script = var.tpcc_script_zip_path
      }
    }
  )

}

resource "null_resource" "control_models_deploy" {

    count = var.cluster_number

    provisioner "local-exec" {
      command = "juju deploy --model control-mysql-${count.index} ${local_file.control_bundle.filename}"
    }

    depends_on = [module.control_models, local_file.control_bundle, module.deploy_cos]
}