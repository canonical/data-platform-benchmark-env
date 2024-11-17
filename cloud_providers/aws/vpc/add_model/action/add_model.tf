#data "local_file" "juju_controller_yaml" {
#  # filename = pathexpand("~/juju-controller.yaml")
#  filename = pathexpand("~/.local/share/juju/controllers.yaml")
#}

provider "juju" {
  alias = "aws-juju"

  controller_addresses = var.controller_info.api_endpoints
  username = var.controller_info.username
  password = var.controller_info.password
  ca_certificate = var.controller_info.ca_cert

#  controller_addresses = yamlencode(data.local_file.juju_controller_yaml.content)["controllers"][var.controller_name]["api_endpoints"]
#  username = yamlencode(data.local_file.juju_controller_yaml.content)["controllers"][var.controller_name]["username"]
#  password = yamlencode(data.local_file.juju_controller_yaml.content)["controllers"][var.controller_name]["password"]
#  ca_certificate = base64decode(yamlencode(data.local_file.juju_controller_yaml.content)["controllers"][var.controller_name]["ca_cert"])
}

module "add_model" {
    source = "git::https://github.com/canonical/data-platform-benchmark-env//cloud_providers/aws/vpc/add_model?ref=aws-extend-multi-subnets"

    providers = {
        juju = juju.aws-juju
    }

    model_name = var.model_name
    region = var.vpc.region
    vpc_id = var.vpc_id
    spaces = var.spaces

}
