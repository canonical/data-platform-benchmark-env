variable "AWS_ACCESS_KEY" {
    type      = string
    sensitive = true
}

variable "AWS_SECRET_KEY" {
    type      = string
    sensitive = true
}

variable "agent_version" {
    type = string
    default = ""
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

variable "microk8s_ips" {
  type = list(list(string))
  default = [
    ["192.168.235.201", "192.168.235.202", "192.168.235.203"],
    ["192.168.235.205", "192.168.235.206", "192.168.235.207"]
  ]
}

variable "number_of_clusters" {
  type = number
  default = 2
}

/*
variable "microk8s_ips_1" {
  type = list(string)
  default = ["192.168.235.201", "192.168.235.202", "192.168.235.203"]
}

variable "microk8s_ips_2" {
  type = list(string)
  default = ["192.168.235.205", "192.168.235.206", "192.168.235.207"]
}
*/

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
    source = "../../cloud_providers/aws/single_az/setup/"

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
    source = "../../cloud_providers/aws/single_az/bootstrap/"

    aws_creds_name = "aws_creds_us_east_1"
    vpc_id = module.aws_vpc.vpc_id
    private_cidr = module.aws_vpc.private_cidr
    AWS_ACCESS_KEY = var.AWS_ACCESS_KEY
    AWS_SECRET_KEY = var.AWS_SECRET_KEY
    agent_version = var.agent_version

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
//           Deploy models in Juju
// --------------------------------------------------------------------------------------

module "create_microk8s_vm" {
    source = "../../cloud_providers/aws/microk8s/"

    count = var.number_of_clusters

    providers = {
        aws = aws.us-east1
    }

    vpc_id = module.aws_vpc.vpc_id
    private_subnet_id = module.aws_vpc.private_subnet_id
    security_group_name = "microk8s-${count.index}"
    aws_key_name = module.aws_vpc.key_name
    private_key_path = module.aws_vpc.private_key_file
    public_key_path = module.aws_vpc.public_key_file
    ami_id = module.aws_vpc.ami_id
    vpc_cidr = module.aws_vpc.vpc.cidr
    microk8s_ips = element(var.microk8s_ips, count.index)

    depends_on = [module.sshuttle]
}

module "microk8s_models" {
    source = "../../cloud_providers/aws/single_az/add_model/"

    count = var.number_of_clusters

    providers = {
        juju = juju.aws-juju
    }

    name = "microk8s-${count.index}"
    region = module.aws_vpc.vpc.region
    vpc_id = module.aws_vpc.vpc_id
    controller_info = module.aws_juju_bootstrap.controller_info

    depends_on = [module.create_microk8s_vm]
}

module "deploy_microk8s" {
    source = "../../cloud_providers/k8s/microk8s/"

    count = var.number_of_clusters

    providers = {
        juju = juju.aws-juju
    }

    model_name = "microk8s-${count.index}"
    private_key_path = module.aws_vpc.private_key_file
    public_key_path = module.aws_vpc.public_key_file
    microk8s_charm_channel = "1.28/stable"
    vpc_cidr = module.aws_vpc.vpc.cidr
    microk8s_ips = element(var.microk8s_ips, count.index)
    microk8s_kubeconfig = "~/.kube/mk8s_tf_config_${count.index}"

    depends_on = [module.microk8s_models]

}

/*
module "create_microk8s_vm_1" {
    source = "../../cloud_providers/aws/microk8s/"

    providers = {
        aws = aws.us-east1
    }

    vpc_id = module.aws_vpc.vpc_id
    private_subnet_id = module.aws_vpc.private_subnet_id
    security_group_name = "microk8s-1"
    aws_key_name = module.aws_vpc.key_name
    private_key_path = module.aws_vpc.private_key_file
    public_key_path = module.aws_vpc.public_key_file
    ami_id = module.aws_vpc.ami_id
    vpc_cidr = module.aws_vpc.vpc.cidr
    microk8s_ips = var.microk8s_ips_1

    depends_on = [module.sshuttle]

}

module "create_microk8s_vm_2" {
    source = "../../cloud_providers/aws/microk8s/"

    providers = {
        aws = aws.us-east1
    }

    vpc_id = module.aws_vpc.vpc_id
    private_subnet_id = module.aws_vpc.private_subnet_id
    security_group_name = "microk8s-2"
    aws_key_name = module.aws_vpc.key_name
    private_key_path = module.aws_vpc.private_key_file
    public_key_path = module.aws_vpc.public_key_file
    ami_id = module.aws_vpc.ami_id
    vpc_cidr = module.aws_vpc.vpc.cidr
    microk8s_ips = var.microk8s_ips_2

    depends_on = [module.sshuttle]
}

module "control_models" {
    source = "../../single_az/add_model/"

    count = var.cluster_number

    providers = {
        juju = juju.aws-juju
    }

    name = "control-mysql-${count.index}"
    region = module.aws_vpc.vpc.region
    vpc_id = module.aws_vpc.vpc_id
    controller_info = module.aws_juju_bootstrap.controller_info

    depends_on = [module.aws_juju_bootstrap]

}

module "deploy_microk8s_1" {
    source = "../../cloud_providers/k8s/microk8s/"

    providers = {
        juju = juju.aws-juju
    }

    model_name = "microk8s-1"
    private_key_path = module.aws_vpc.private_key_file
    public_key_path = module.aws_vpc.public_key_file
    microk8s_charm_channel = "1.28/stable"
    vpc_cidr = module.aws_vpc.vpc.cidr
    microk8s_ips = var.microk8s_ips_1
    microk8s_kubeconfig = "~/.kube/mk8s_tf_config"

    depends_on = [module.create_microk8s_vm_1]

}

module "deploy_microk8s_2" {
    source = "../../cloud_providers/k8s/microk8s/"

    providers = {
        juju = juju.aws-juju
    }

    model_name = "microk8s-2"
    private_key_path = module.aws_vpc.private_key_file
    public_key_path = module.aws_vpc.public_key_file
    microk8s_charm_channel = "1.28/stable"
    vpc_cidr = module.aws_vpc.vpc.cidr
    microk8s_ips = ["192.168.235.201", "192.168.235.202", "192.168.235.203"]
    microk8s_kubeconfig = "~/.kube/mk8s_tf_config"

    depends_on = [module.create_microk8s_vm_2]
}
*/