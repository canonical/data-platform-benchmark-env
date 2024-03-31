provider "aws" {
  alias = "us-east1"

  region = var.vpc.region
  access_key = var.ACCESS_KEY_ID
  secret_key = var.SECRET_KEY
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
    AWS_ACCESS_KEY = var.ACCESS_KEY_ID
    AWS_SECRET_KEY = var.SECRET_KEY
}

module "sshuttle" {
    source = "../../utils/sshuttle/"

    jumphost_ip = module.aws_vpc.jumphost_elastic_ip
    subnet = module.aws_vpc.vpc.cidr
    private_key_filepath = module.aws_vpc.private_key_file

    depends_on = [module.aws_vpc]
}

# TODO: Make it more flexible, by creating a "juju.tf" which can bootstrap on any cloud
module "aws_juju_bootstrap" {
    source = "../../cloud_providers/aws/vpc/single_az/bootstrap/"

    aws_creds_name = "aws_creds_us_east_1"
    vpc_id = module.aws_vpc.vpc_id
    private_cidr = module.aws_vpc.private_cidr
    AWS_ACCESS_KEY = var.ACCESS_KEY_ID
    AWS_SECRET_KEY = var.SECRET_KEY
    agent_version = var.agent_version

    build_agent_path = var.juju_build_agent_path

    depends_on = [module.sshuttle]
}