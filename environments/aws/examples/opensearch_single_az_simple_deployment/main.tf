variable "AWS_ACCESS_KEY" {
    type      = string
    sensitive = true
}

variable "AWS_SECRET_KEY" {
    type      = string
    sensitive = true
}

variable "microk8s_model_name" {
    type = string
    default = "microk8s"
}

variable "vpc" {
  type = object({
    name   = string
    region = string
    az     = string
    cidr   = string
  })
  default = {
    name   = "test-vpc"
    region = "us-east-1"
    az     = "us-east-1a"
    cidr   = "192.168.234.0/23"
  }
}

// --------------------------------------------------------------------------------------
//           Providers to be used
// --------------------------------------------------------------------------------------


terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = ">= 4.0.4"
    }
    local = {
      source = "hashicorp/local"
      version = ">= 2.4.0"
    }
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
    external = {
      source = "hashicorp/external"
      version = ">=2.3.2"
    }
  }
}

provider "aws" {
  alias = "us-east1"

  region = var.vpc.region
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}


// --------------------------------------------------------------------------------------
//           Setup environment
// --------------------------------------------------------------------------------------


module "aws_vpc" {
    source = "../../single_az/setup/"

    providers = {
        aws = aws.us-east1
    }

    vpc = var.vpc
    AWS_ACCESS_KEY = var.AWS_ACCESS_KEY
    AWS_SECRET_KEY = var.AWS_SECRET_KEY
}

module "sshuttle" {
    source = "../../../../utils/sshuttle/"

    jumphost_ip = module.aws_vpc.jumphost_elastic_ip
    subnet = module.aws_vpc.vpc.cidr
    private_key_filepath = module.aws_vpc.private_key_file

    depends_on = [module.aws_vpc]
}

module "aws_juju_bootstrap" {
    source = "../../single_az/bootstrap/"

    aws_creds_name = "aws_creds_us_east_1"
    vpc_id = module.aws_vpc.vpc_id
    private_cidr = module.aws_vpc.private_cidr
    AWS_ACCESS_KEY = var.AWS_ACCESS_KEY
    AWS_SECRET_KEY = var.AWS_SECRET_KEY

    depends_on = [module.sshuttle]
}

provider "juju" {
  alias = "aws-juju"

  controller_addresses = module.aws_juju_bootstrap.controller_info.api_endpoints
  username = module.aws_juju_bootstrap.controller_info.username
  password = module.aws_juju_bootstrap.controller_info.password
  ca_certificate = module.aws_juju_bootstrap.controller_info.ca_cert
}

module "add_microk8s_model" {
    source = "../../single_az/add_model/"

    providers = {
        juju = juju.aws-juju
    }

    name = var.microk8s_model_name
    region = module.aws_vpc.vpc.region
    vpc_id = module.aws_vpc.vpc_id
    controller_info = module.aws_juju_bootstrap.controller_info

    depends_on = [module.aws_juju_bootstrap]

}


module "deploy_cos" {
    source = "../cos_microk8s_deployment/"

    providers = {
        aws = aws.us-east1
        juju = juju.aws-juju
    }

    model_name = var.microk8s_model_name
    vpc_id = module.aws_vpc.vpc_id
    private_subnet_id = module.aws_vpc.private_subnet_id
    aws_key_name = module.aws_vpc.key_name
    aws_private_key_path = module.aws_vpc.private_key_file
    public_key_path = pathexpand("~/.ssh/id_rsa.pub")
    private_key_path = pathexpand("~/.ssh/id_rsa")
    controller_name = module.aws_juju_bootstrap.controller_name

    ami_id = module.aws_vpc.ami_id
    cos_microk8s_bundle = pathexpand("../../../cos/deploy/bundle.yaml")
    cos_microk8s_overlay = pathexpand("../../../cos/deploy/offers-overlay.yaml")

    depends_on = [module.add_microk8s_model]
}


// --------------------------------------------------------------------------------------
//           Deploy control models in Juju
// --------------------------------------------------------------------------------------


module "opensearch_model" {
    source = "../../single_az/add_model/"

    providers = {
        juju = juju.aws-juju
    }

    name = "opensearch"
    region = module.aws_vpc.vpc.region
    vpc_id = module.aws_vpc.vpc_id
    controller_info = module.aws_juju_bootstrap.controller_info

    depends_on = [module.aws_juju_bootstrap]

}

variable "opensearch_bundle_params" {
  type = object({
    opensearch-charm            = string
    opensearch-channel-entry    = string
  })
  default = {
    opensearch-charm            = "opensearch"
    opensearch-channel-entry    = ""
  }
}

resource "local_file" "opensearch_bundle" {

  filename = "${path.module}/opensearch_bundle.yaml"

  content = templatefile(
    "${path.module}/../../../../scenarios/vm/simple_opensearch/bundle.yaml",
    {
      params = var.opensearch_bundle_params
    }
  )

}

resource "null_resource" "opensearch_model_deploy" {

    provisioner "local-exec" {
      command = "juju deploy --model opensearch ${local_file.opensearch_bundle.filename}"
    }

    depends_on = [module.opensearch_model, local_file.opensearch_bundle, module.deploy_cos]
}


// --------------------------------------------------------------------------------------
//           Wait for deployment
// --------------------------------------------------------------------------------------


resource "null_resource" "wait_for_deploy" {

    provisioner "local-exec" {
      command = <<-EOT
      juju-wait --model opensearch;
      EOT
    }

    depends_on = [null_resource.opensearch_model_deploy]
}