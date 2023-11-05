variable "private_cidr" {
    type = string
    default = "192.168.235.0/24"
}

module "aws_vpc" {
    source = "../setup/"

    vpc = {
        name = "test-vpc"
        region = "us-east-1"
        az = "us-east-1a"
        cidr = "192.168.234.0/23"
        private_cidr = var.private_cidr
        public_cidr  = "192.168.234.0/24"
    }

}

module "aws_juju_bootstrap" {
    source = "../bootstrap/"

    aws_creds_name = "aws_creds_us_east_1"
    vpc_id = module.aws_vpc.vpc_id
}

module "microk8s_for_cos_add_model" {
    source = "../add_model/"

    name = "cos-microk8s"
    vpc_id = module.aws_vpc.vpc_id
    spaces = {
        name    = "internal-space"
        subnets = [var.private_cidr]
    }
}

module "microk8s_deploy" {
    source = "../../../k8s/microk8s/deploy/"

    model_name = module.microk8s_for_cos_add_model.name
    hostpath_storage = true
    constraints = {
        instance_type = "t2.large"
        spaces = module.microk8s_for_cos_add_model.spaces[*].name
    }
}

// Workaround as we are not exposing microk8s with aws integrator
resource "terraform_data" "microk8s_expose" {
    provider "local-exec" {
        command = "juju exec --unit microk8s/0 'open-port 10000-50000'"
    }
    depends-on = ["microk8s_deploy"]
}

#// Implements the metallb workaround: to set multiple secondary IPs for metallb to use
#resource "terraform_data" "metallb_workaround" {
#
#}