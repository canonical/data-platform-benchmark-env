terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.1"
    }
    external = {
      source = "hashicorp/external"
      version = ">=2.3.2"
    }
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
  }
}

variable "model_name" {
    type = string
}

variable "opensearch_constraints" {
    type = object({
      instance_type = string
      spaces = string
      root-disk = string
      data-disk = string
      channel = string
    })
}

variable "opensearch_count" {
    type = number
    default = 3
}

variable "opensearch_base" {
    type = string
    default = "ubuntu@22.04"
}

variable "opensearch_channel" {
    type = string
    default = "2/edge"
}

variable "tls-operator-integration" {
    type = string
}

variable grafana-dashboard-integration {
  type = string
}

variable "logging-integration" {
    type = string
}

variable "prometheus-scrape-integration" {
    type = string
}

variable "prometheus-receive-remote-write-integration" {
    type = string
}

variable "sysconfig-options" {
    type = string
    default = "{ vm.max_map_count: 262144, vm.swappiness: 0, net.ipv4.tcp_retries2: 5 }"
}

variable "opensearch_expose" {
    type = bool
    default = false
}

variable "grafana-agent-appname" {
    type = string
    default = "grafana-agent"
}

variable "sysconfig-appname" {
    type = string
    default = "sysconfig"
}

locals {
    cos_offerings = {
        "grafana-dashboard" = {
            name = juju_application.grafana-agent.name
            endpoint = "monitoring"
            offer-url = var.grafana-dashboard-integration
        },
        "logging" = {
            name = juju_application.grafana-agent.name
            endpoint = "monitoring"
            offer-url = var.logging-integration
        },
        "prometheus-scrape" = {
            name = juju_application.grafana-agent.name
            endpoint = "monitoring"
            offer-url = var.prometheus-scrape-integration
        },
        "prometheus-receive-remote-write" = {
            name = juju_application.grafana-agent.name
            endpoint = "monitoring"
            offer-url = var.prometheus-receive-remote-write-integration
        },
    }
}

// --------------------------------------------------------------------------------------
//           OpenSearch Deployment
// --------------------------------------------------------------------------------------

resource "juju_machine" "opensearch_nodes" {
  count = var.opensearch_count

  base = var.opensearch_base

  model = var.model_name
  constraints = join(" ", [
    for k,v in {
        "instance-type" = var.opensearch_constraints.instance_type
        "root-disk" = var.opensearch_constraints.root-disk
        "spaces" = var.opensearch_constraints.spaces
    } : "${k}=${v}"
  ])
}

resource "juju_application" "opensearch" {
    name = "opensearch"
    model = var.model_name
    charm {
        name = "opensearch"
        channel = var.opensearch_channel
        base = var.opensearch_base
    }
    units = var.opensearch_count
    placement = join(",", [for machine in juju_machine.opensearch_nodes : machine.machine_id])
    depends_on = [juju_machine.opensearch_nodes]
}

resource "juju_application" "sysconfig" {
    name = var.sysconfig-appname
    model = var.model_name
    charm {
        name = "sysconfig"
        channel = "latest/stable"
        base = var.opensearch_base
    }
    config = {
        "sysctl" = var.sysconfig-options
    }
    depends_on = [juju_machine.opensearch_nodes]
}

resource "juju_application" "grafana-agent" {
    name = var.grafana-agent-appname
    model = var.model_name
    charm {
        name = "grafana-agent"
        channel = "latest/stable"
        base = var.opensearch_base
    }
    depends_on = [juju_machine.opensearch_nodes]
}

// --------------------------------------------------------------------------------------
//           Integration
// --------------------------------------------------------------------------------------

resource "juju_integration" "opensearch_grafana_sysconfig-integrations" {
    model = var.model_name

    for_each = {
        relation1 = {
            name_req = juju_application.opensearch.name
            endpoint_req = "monitoring"
            name_prov = var.grafana-agent-appname
            endpoint_prov = "monitoring"
        },
        relation2 = {
            name_req = juju_application.opensearch.name
            endpoint_req = "juju-info"
            name_prov = var.sysconfig-appname
            endpoint_prov = "juju-info"
        }
    }
    application {
        name     = each.value.name_req
        endpoint = each.value.endpoint_req
    }
    application {
        name     = each.value.name_prov
        endpoint = each.value.endpoint_prov
    } 
}

resource "juju_integration" "grafana-agent_cos-integration" {
    model = var.model_name

    for_each = local.cos_offerings
    application {
        name = each.value.name
        endpoint = each.value.endpoint
    }
    application {
        offer_url = each.value.offer-url
    }
}
