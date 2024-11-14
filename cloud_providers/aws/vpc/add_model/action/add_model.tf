data "local_file" "juju_controller_yaml" {
  # filename = pathexpand("~/juju-controller.yaml")
  filename = pathexpand("~/.local/share/juju/controllers.yaml")

  depends_on = [module.aws_juju_bootstrap]
}

provider "juju" {
  alias = "aws-juju"

  controller_addresses = yamlencode(data.local_file.juju_controller_yaml.content)["api_endpoints"]
  username = yamlencode(data.local_file.juju_controller_yaml.content)["username"]
  password = yamlencode(data.local_file.juju_controller_yaml.content)["password"]
  ca_certificate = base64decode(yamlencode(data.local_file.juju_controller_yaml.content)["ca_cert"])
}

module "add_model" {
    source = "git::https://github.com/canonical/data-platform-benchmark-env//cloud_providers/aws/vpc/add_model?ref=aws-extend-multi-subnets"

    providers = {
        juju = juju.aws-juju
    }

    name = var.model_name
    region = module.aws_vpc.vpc.region
    vpc_id = module.aws_vpc.vpc_id
    controller_info = module.aws_juju_bootstrap.controller_info

    depends_on = [module.aws_juju_bootstrap]
}