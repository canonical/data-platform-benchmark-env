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

variable "opensearch_charm_channel" {
    type = string
    default = "2/edge"
}

variable "agent_version" {
    type = string
    default = ""
}

variable "juju_build_agent_path" {
    type = string
    default = ""
}

variable "juju_git_branch" {
    type = string
    default = ""
}

variable "microk8s_ips" {
    type = list(string)
    default = ["192.168.235.201", "192.168.235.202", "192.168.235.203"]
}

variable "microk8s_cloud_name" {
    type = string
    default = "test-k8s"
}

variable cos_bundle {
  type = string
  default = "../../cloud_providers/k8s/cos/bundle.yaml"
}

variable cos_overlay_bundle {
  type = string
  default = "../../cloud_providers/k8s/cos/cos-overlay.yaml"
}

variable cos_model_name {
  type = string
  default = "cos"
}

variable charmed_k8s_model_name {
  type = string
  default = "charmed-k8s"
}

variable metallb_model_name {
  type = string
  default = "metallb"
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

variable "spaces" {
  type = list(object({
    name = string
    subnets = list(string)
  }))
    default = [
    {
      name = "internal-space"
      subnets = ["192.168.235.0/24"]
    },
  ]
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
    source = "../../cloud_providers/aws/vpc/single_az/setup/"

    providers = {
        aws = aws.us-east1
    }

    vpc = var.vpc
    AWS_ACCESS_KEY = var.AWS_ACCESS_KEY
    AWS_SECRET_KEY = var.AWS_SECRET_KEY
}

module "sshuttle" {
    source = "../../utils/sshuttle/"

    jumphost_ip = module.aws_vpc.jumphost_elastic_ip
    subnet = module.aws_vpc.vpc.cidr
    private_key_filepath = module.aws_vpc.private_key_file

    depends_on = [module.aws_vpc]
}

module "aws_juju_bootstrap" {
    source = "../../cloud_providers/aws/vpc/single_az/bootstrap/"

    aws_creds_name = "aws_creds_us_east_1"
    vpc_id = module.aws_vpc.vpc_id
    private_cidr = module.aws_vpc.private_cidr
    AWS_ACCESS_KEY = var.AWS_ACCESS_KEY
    AWS_SECRET_KEY = var.AWS_SECRET_KEY
    agent_version = var.agent_version

    build_agent_path = var.juju_build_agent_path

    depends_on = [module.sshuttle]
}

provider "juju" {
  alias = "aws-juju"

#  controller_addresses = "192.168.235.55:17070"
  controller_addresses = module.aws_juju_bootstrap.controller_info.api_endpoints
  username = module.aws_juju_bootstrap.controller_info.username
  password = module.aws_juju_bootstrap.controller_info.password
  ca_certificate = module.aws_juju_bootstrap.controller_info.ca_cert
}

resource juju_model ubuntu {
  name = "ubuntu"
  provider = juju.aws-juju

  provisioner local-exec {
    command = "juju add-space internal-space 192.168.235.0/24"
  }

  config = {
    "vpc-id" = module.aws_vpc.vpc_id
    "vpc-id-force" = "true"
  }

  depends_on = [module.sshuttle]
}

resource "null_resource" "add_space" {
  triggers = {
    api_endpoints = module.aws_juju_bootstrap.controller_info.api_endpoints
  }

  # Remove the fan-networking from model-config by setting container-networking-method=local
  provisioner "local-exec" {
    command = <<-EOT
    juju add-space internal-space 192.168.235.0/24
    echo "The controller API endpoints are: ${module.aws_juju_bootstrap.controller_info.api_endpoints}"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
    echo "The controller API endpoints are: ${self.triggers.api_endpoints}"
    EOT
  }

  depends_on = [juju_model.ubuntu]
}

resource juju_application ubuntu {
  name = "ubuntu"

  model = juju_model.ubuntu.name
  charm {
    name = "ubuntu"
    channel = "latest/stable"
  }

  constraints = join(" ", [
      for k, v in {
      "instance-type" = "t3.medium"
      "root-disk" = "100G"
      "spaces" = "internal-space"
    } : "${k}=${v}"
  ])

  units = 1

  depends_on = [juju_model.ubuntu]
}
