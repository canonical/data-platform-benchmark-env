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

variable "cluster_number" {
    default = 3
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

variable "cni_cidr" {
  type = string
  default = "10.10.10.0/24"
}

variable "service_cidr" {
  type = string
  default = "10.20.20.0/24"
}

variable worker_count {
  type = number
  default = 3
}

variable "microk8s_cloud_name" {
    type = string
    default = "test-k8s"
}

variable "microk8s_ips" {
    type = list(string)
    default = ["192.168.235.201", "192.168.235.202", "192.168.235.203"]
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

    depends_on = [module.sshuttle]
}

provider "juju" {
  alias = "aws-juju"

  controller_addresses = module.aws_juju_bootstrap.controller_info.api_endpoints
  username = module.aws_juju_bootstrap.controller_info.username
  password = module.aws_juju_bootstrap.controller_info.password
  ca_certificate = module.aws_juju_bootstrap.controller_info.ca_cert
}

// --------------------------------------------------------------------------------------
//           Deploy COS
// --------------------------------------------------------------------------------------

module "deploy_k8s_vm" {
  source = "../../cloud_providers/aws/k8s/microk8s/"

  providers = {
      aws = aws.us-east1
  }

  vpc_id = module.aws_vpc.vpc_id
  private_subnet_id = module.aws_vpc.private_subnet_id
  aws_key_name = module.aws_vpc.key_name
  aws_private_key_path = module.aws_vpc.private_key_file
  public_key_path = pathexpand("~/.ssh/id_rsa.pub")
  private_key_path = pathexpand("~/.ssh/id_rsa")
  vpc_cidr = module.aws_vpc.vpc.cidr
  ami_id = module.aws_vpc.ami_id
  microk8s_ips = var.microk8s_ips

  depends_on = [module.sshuttle]
}

module "add_microk8s_model" {
    source = "../../cloud_providers/aws/vpc/single_az/add_model/"

    providers = {
        juju = juju.aws-juju
    }

    name = var.microk8s_model_name
    region = module.aws_vpc.vpc.region
    vpc_id = module.aws_vpc.vpc_id
    controller_info = module.aws_juju_bootstrap.controller_info

    depends_on = [module.deploy_k8s_vm]

}

module "microk8s_app" {
  source = "../../cloud_providers/k8s/bootstrap/microk8s/"

  providers = {
      juju = juju.aws-juju
  }

  model_name = var.microk8s_model_name
  public_key_path = pathexpand("~/.ssh/id_rsa.pub")
  private_key_path = pathexpand("~/.ssh/id_rsa")
  vpc_cidr = module.aws_vpc.vpc.cidr
  microk8s_ips = var.microk8s_ips
  microk8s_charm_channel = "1.28/stable"

  depends_on = [module.add_microk8s_model]
}

// Add the microk8s cloud
module "microk8s_cloud" {
  source = "../../cloud_providers/k8s/add_k8s/"

  controller_name = module.aws_juju_bootstrap.controller_info.name
  microk8s_cloud_name = var.microk8s_cloud_name
  microk8s_host_details = {
    ip = module.deploy_k8s_vm.microk8s_private_ip
    private_key_path = module.deploy_k8s_vm.id_rsa_pub_key

  }

  depends_on = [module.microk8s_app]
}

resource "juju_model" "cos_model" {

  name = var.cos_model_name
  cloud {
    name = var.microk8s_cloud_name
  }

  credential = var.microk8s_cloud_name

  config = {
    logging-config              = "<root>=INFO"
    development                 = true
    no-proxy                    = "jujucharms.com"
    update-status-hook-interval = "5m"
  }
  depends_on = [module.microk8s_cloud]
}

module "cos" {
  source = "../../cloud_providers/k8s/cos/"

  providers = {
      juju = juju.aws-juju
  }

  cos_bundle = var.cos_bundle
  cos_overlay = var.cos_overlay_bundle
  cos_model_name = var.cos_model_name

  depends_on = [juju_model.cos_model]
}


// --------------------------------------------------------------------------------------
//           Deploy multiple charmed k8s in Juju
// --------------------------------------------------------------------------------------

module "add_charmed_k8s_models" {
    source = "../../cloud_providers/aws/vpc/single_az/add_model/"

    count = var.cluster_number

    providers = {
        juju = juju.aws-juju
    }

    name = "${var.charmed_k8s_model_name}-${count.index}"
    region = module.aws_vpc.vpc.region
    vpc_id = module.aws_vpc.vpc_id
    controller_info = module.aws_juju_bootstrap.controller_info

    depends_on = [module.aws_juju_bootstrap]

}

module "charmed_k8s" {
    source = "../../cloud_providers/k8s/bootstrap/charmed_k8s/"

    count = var.cluster_number

    providers = {
        juju = juju.aws-juju
    }

    cos = {
        model_name = var.cos_model_name
        bundle = var.cos_bundle
        overlay = var.cos_overlay_bundle
    }
    k8s_model = "${var.charmed_k8s_model_name}-${count.index}"
    cni_cidr = var.cni_cidr
    service_cidr = var.service_cidr
    k8s_control_num_units = 3
    k8s_control_constraints = {
      instance_type = "c6a.xlarge"
      root_disk_size = "400G"
      spaces = ["internal-space"]
    }
    k8s_worker_num_units = var.worker_count

    depends_on = [module.add_charmed_k8s_models, module.cos]

}
