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

module "sshuttle_bootstrap" {
    source = "../../utils/sshuttle/"

    jumphost_ip = module.aws_vpc.jumphost_elastic_ip
    subnet = module.aws_vpc.vpc.cidr
    private_key_filepath = module.aws_vpc.private_key_file

    depends_on = [module.aws_vpc]
}

// --------------------------------------------------------------------------------------
//           Juju Controller Setup
// --------------------------------------------------------------------------------------

# TODO: Make it more flexible, by creating a "juju.tf" which can bootstrap on any cloud
module "aws_juju_bootstrap" {
    source = "../../cloud_providers/aws/vpc/single_az/bootstrap/"

    aws_creds_name = "aws_creds_us_east_1"
    vpc_id = module.aws_vpc.vpc_id
    private_cidr = module.aws_vpc.private_cidr
    AWS_ACCESS_KEY = var.ACCESS_KEY_ID
    AWS_SECRET_KEY = var.SECRET_KEY
    agent_version = var.agent_version
    fan_networking_cidr = var.fan_networking_cidr

    build_agent_path = var.juju_build_agent_path

    depends_on = [module.sshuttle_bootstrap]
}

// --------------------------------------------------------------------------------------
//           Juju Controller Output
// --------------------------------------------------------------------------------------

resource "local_file" "controller_info" {
  filename = pathexpand("/tmp/juju_show_controller.sh")
  content = <<-EOT
  #!/bin/bash
  jq -n --arg ctl "$(juju show-controller --show-password)" '{"output": $ctl}'
  EOT
  file_permission = "0700"
  depends_on = [module.aws_juju_bootstrap]
}

data "external" "juju_controller_info" {
  program = ["bash", local_file.controller_info.filename]
  depends_on = [local_file.controller_info]
}

locals {
  juju_endpoints = join(",", yamldecode(data.external.juju_controller_info.result["output"])[module.aws_juju_bootstrap.controller_name]["details"]["api-endpoints"])
}

# Removes any fan-network-method
data "external" "controller_api_endpoints_without_fan_networking" {
  program = ["python3", "-c", "import ipaddress; print( '{ \"output\": \"' + ','.join([ip for ip in '${local.juju_endpoints}'.split(',') if ipaddress.IPv4Address(ip.split(':')[0]) not in ipaddress.IPv4Network('${var.fan_networking_cidr}')]) + '\" }' );"]

  depends_on = [local_file.juju_controller_info]
}

resource null_resource "aws_sql_bench_bootstrap" {
    depends_on = [
        module.aws_juju_bootstrap,
        data.external.controller_api_endpoints_without_fan_networking
    ]
}

output "controller_info" {
  description = "Controller info"
  value = {
      name = module.aws_juju_bootstrap.controller_name
      api_endpoints = data.external.controller_api_endpoints_without_fan_networking.result["output"]
      ca_cert = yamldecode(data.external.juju_controller_info.result["output"])[module.aws_juju_bootstrap.controller_name]["details"]["ca-cert"]
      username = yamldecode(data.external.juju_controller_info.result["output"])[module.aws_juju_bootstrap.controller_name]["account"]["user"]
      password = yamldecode(data.external.juju_controller_info.result["output"])[module.aws_juju_bootstrap.controller_name]["account"]["password"]        
  }
}