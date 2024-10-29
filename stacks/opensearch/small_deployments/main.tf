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

variable "constraints" {
    type = object({
      instance_type = string
      spaces = string
      root-disk = string
      data-disk = string
      channel = string
    })
}

variable "node_count" {
    type = number
    default = 3
}

variable "base" {
    type = string
    default = "ubuntu@22.04"
}

variable "channel" {
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

variable "expose" {
    type = bool
    default = false
}

variable "grafana-agent-appname" {
    type = string
    default = "grafana-agent"
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

resource "juju_application" "opensearch" {
    name = "opensearch"
    model = var.model_name
    charm {
        name = "opensearch"
        channel = var.channel
        base = var.base
    }

    constraints = join(" ", [
      for k,v in {
          "instance-type" = var.constraints.instance_type
          "root-disk" = var.constraints.root-disk
          "spaces" = var.constraints.spaces
      } : "${k}=${v}"
    ])

    units = var.node_count
#    placement = join(",", [for machine in juju_machine.opensearch_nodes : machine.machine_id])
#    depends_on = [juju_machine.opensearch_nodes]
}

resource "juju_application" "grafana-agent" {
    name = var.grafana-agent-appname
    model = var.model_name
    charm {
        name = "grafana-agent"
        channel = "latest/stable"
        base = var.base
    }
    depends_on = [juju_application.opensearch]
}

// --------------------------------------------------------------------------------------
//           Integration
// --------------------------------------------------------------------------------------

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
