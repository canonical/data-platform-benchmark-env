// --------------------------------------------------------------------------------------
//           Setup environment
// --------------------------------------------------------------------------------------

provider "aws" {
  alias = "us-east1"

  region = var.vpc.region
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY

  default_tags {
    tags = var.provider_tags
  }
}

// --------------------------------------------------------------------------------------
//           Setup environment
// --------------------------------------------------------------------------------------

module "aws_vpc" {
    source = "git::https://github.com/canonical/data-platform-benchmark-env//cloud_providers/aws/vpc/setup?ref=aws-extend-multi-subnets"

    providers = {
        aws = aws.us-east1
    }

    vpc = var.vpc
    access_key = var.AWS_ACCESS_KEY
    secret_key = var.AWS_SECRET_KEY
}

module "sshuttle_bootstrap" {
    source = "git::https://github.com/canonical/data-platform-benchmark-env//utils/sshuttle?ref=aws-extend-multi-subnets"

    jumphost_ip = module.aws_vpc.jumphost_elastic_ip
    subnet = module.aws_vpc.vpc.cidr
    private_key_filepath = module.aws_vpc.private_key_file

    depends_on = [module.aws_vpc]
}

// --------------------------------------------------------------------------------------
//           Juju Controller Setup
// --------------------------------------------------------------------------------------

module "aws_juju_bootstrap" {
    source = "git::https://github.com/canonical/data-platform-benchmark-env//cloud_providers/aws/vpc/bootstrap?ref=aws-extend-multi-subnets"

    aws_creds_name = "aws_creds_us_east_1"
    vpc_id = module.aws_vpc.vpc_id
    private_cidr = module.aws_vpc.private_cidr
    access_key = var.AWS_ACCESS_KEY
    secret_key = var.AWS_SECRET_KEY
    agent_version = var.agent_version
    fan_networking_cidr = var.fan_networking_cidr

    build_agent_path = var.juju_build_agent_path

    depends_on = [module.sshuttle_bootstrap]
}
