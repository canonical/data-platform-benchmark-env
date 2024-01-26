variable "model_name" {
    type = string
}

variable "opensearch_constraints" {
    type = object({
      instance_type = string
      spaces = map(string)
      root-disk = string
      data-disk = string
      base = string
      channel = string
      count = number
    })
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

// --------------------------------------------------------------------------------------
//           OpenSearch Deployment
// --------------------------------------------------------------------------------------

resource "juju_machine" "opensearch_nodes" {
  for_each = var.opensearch_constraints.count

  model = var.model_name
  constraints = {
    "instance-type" = var.opensearch_constraints.instance_type
    "root-disk" = var.opensearch_constraints.root-disk
    "data-disk" = var.opensearch_constraints.data-disk
    "base" = var.opensearch_constraints.base
    "spaces" = var.opensearch_constraints.spaces
  }
}

resource "juju_application" "opensearch" {
    name = "opensearch"
    model = var.model_name
    charm {
        name = "opensearch"
        channel = var.opensearch.nodes.channel
        base = var.opensearch.nodes.base
    }
    expose = var.opensearch_expose
    units = var.opensearch_nodes.count
    placement = join(",", [for machine in juju_machine.opensearch_nodes : machine.machine_id])
    depends_on = [juju_machine.opensearch_nodes]
}

resource "juju_application" "sysconfig" {
    name = "sysconfig"
    model = var.model_name
    charm {
        name = "sysconfig"
        channel = "latest/stable"
        base = var.opensearch_nodes.base
    }
    config = {
        "sysconfig-options" = var.sysconfig-options
    }
    depends_on = [juju_machine.opensearch_nodes]

}

resource "juju_application" "grafana-agent" {
    name = "grafana-agent"
    model = var.model_name
    charm {
        name = "grafana-agent"
        channel = "latest/stable"
        base = var.opensearch_nodes.base
    }
    depends_on = [juju_machine.opensearch_nodes]
}

// --------------------------------------------------------------------------------------
//           Integration
// --------------------------------------------------------------------------------------

resource "juju_integration" "opensearch_grafana_sysconfig-integrations" {
    model = var.model_name

    for_each = tolist(
        {
            name_req = juju_application.opensearch.name
            endpoint_req = "monitoring"
            name_prov = var.grafana-agent.name
            endpoint_prov = "monitoring"
        },
        {
            name_req = juju_application.opensearch.name
            endpoint_req = "juju-info"
            name_prov = var.sysconfig.name
            endpoint_prov = "juju-info"
        }
    )
    application {
        name     = each.value.name_req
        endpoint = each.value.endpoint_req
    }
    application {
        name     = each.value.name_prov
        endpoint = each.value.endpoint_prov
    } 
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

resource "juju_integration" "grafana-agent_cos-integration" {
    model = var.model_name

    for_each = [ for k, v in locals.cos_offerings : v if length(v.offer-url) > 0 ]
    application {
        name = each.name
        endpoint = each.endpoint
    }
    application {
        offer_url = each.offer-url
    }
}