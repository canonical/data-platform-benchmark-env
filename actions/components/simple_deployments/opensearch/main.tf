variable "model_name" {
  description = "Model name"
  type        = string
}

variable "app_name" {
  description = "OpenSearch app name"
  type        = string
  default     = "opensearch-dashboards"
}

variable "opensearch_units" {
  description = "Node count"
  type        = number
  default     = 3
}

variable "opensearch_constraints" {
  description = "OpenSearch constraints"
  type        = string
  default = "arch=amd64 instance-type=m5.2xlarge root-disk=102400 spaces=private-space"
}


variable "opensearch_dashboards_units" {
  description = "OpenSearch dashboards node count"
  type        = number
  default     = 3
}

variable "opensearch_dashboards_constraints" {
  description = "OpenSearch dashboards constraints"
  type        = string
  default = "arch=amd64 instance-type=m5.large root-disk=102400 spaces=private-space"
}

variable "self_signed_cert_constraints" {
  description = "Self-signed cert constraints"
  type        = string
  default = "arch=amd64 instance-type=t2.medium root-disk=102400 spaces=private-space"
}

variable "default_binding" {
  description = "Default spaces"
  type        = string
  default     = "private-space"
}


#resource "null_resource" "preamble" {
#  provisioner "local-exec" {
#    command = <<-EOT
#    sudo snap install juju-wait --classic || true
#    sudo sysctl -w vm.max_map_count=262144 vm.swappiness=0 net.ipv4.tcp_retries2=5
#    EOT
#  }
#
#}

variable "controller_info" {
  type = object({
    name          = string
    api_endpoints = string
    ca_cert       = string
    username      = string
    password      = string
  })
}

variable "spaces" {
  type = list(object({
    name    = string
    subnets = list(string)
  }))
  default = [
    {
      name    = "public-space"
      subnets = ["192.168.234.0/24"]
    },
    {
      name    = "internal-space"
      subnets = ["192.168.235.0/24"]
    },
  ]
}



provider "juju" {
  alias = "aws-juju"

  controller_addresses = var.controller_info.api_endpoints
  username = var.controller_info.username
  password = var.controller_info.password
  ca_certificate = var.controller_info.ca_cert

}

resource "juju_application" "self-signed-certificates" {
  charm {
    name    = "self-signed-certificates"
    channel = "latest/stable"
  }
  model      = var.model_name

  endpoint_bindings = [{
    space = var.default_binding
  }]

#  depends_on = [null_resource.preamble]
}

module "opensearch-dashboards" {
  source     = "git::https://github.com/canonical/opensearch-dashboards-operator//terraform?ref=DPE-5867-opensearch-dashboard-TF"
  app_name   = var.app_name
  model = var.model_name
  units      = var.opensearch_dashboards_units
  constraints = var.opensearch_dashboards_constraints

  channel = "2/edge"

  endpoint_bindings = {
    space = var.default_binding
  }

  depends_on = [juju_application.self-signed-certificates]
}

module "opensearch" {
  source     = "git::https://github.com/canonical/opensearch-operator//terraform?ref=DPE-5866-terraform"
  app_name   = "opensearch"
  model = var.model_name
  units      = var.opensearch_units
  config = {
    profile = "testing"
  }
  constraints = var.opensearch_constraints

  channel = "2/edge"

  endpoint_bindings = {
    space = var.default_binding
  }

  depends_on = [juju_application.self-signed-certificates]
}

resource "juju_integration" "dashboards_opensearch-integration" {
  model = var.model_name

  application {
    name = module.opensearch-dashboards.app_name
    endpoint = module.opensearch-dashboards.opensearch_client_endpoint
  }
  application {
    name = module.opensearch.app_name
    endpoint = module.opensearch.opensearch_client_endpoint
  }
  depends_on = [
    module.opensearch-dashboards,
    module.opensearch
  ]
}

resource "juju_integration" "deployment_tls-operator_opensearch-dashboards-integration" {
  model = var.model_name

  application {
    name = juju_application.self-signed-certificates.name
  }
  application {
    name = module.opensearch.app_name
  }
  depends_on = [
    juju_application.self-signed-certificates,
    module.opensearch
  ]

}


resource "juju_integration" "deployment_tls-operator_opensearch-integration" {
  model = var.model_name

  application {
    name = juju_application.self-signed-certificates.name
  }
  application {
    name = module.opensearch-dashboards.app_name
  }
  depends_on = [
    juju_application.self-signed-certificates,
    module.opensearch
  ]

}

resource "null_resource" "deployment_juju_wait_deployment" {
  provisioner "local-exec" {
    command = <<-EOT
    juju-wait -v --model ${var.model_name}
    EOT
  }

  depends_on = [
    juju_integration.deployment_tls-operator_opensearch-integration,
    juju_integration.dashboards_opensearch-integration,
    juju_integration.deployment_tls-operator_opensearch-dashboards-integration,
  ]
}
