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

variable "cos_model_name" {
  type = string
}

resource "juju_application" "traefik" {
  name = "traefik"
  trust = true

  model = var.cos_model_name
  charm {
    name = "traefik-k8s"
    channel = "stable"
  }
  units = 1
}

resource "juju_application" "alertmanager" {
  name = "alertmanager"
  trust = true

  model = var.cos_model_name
  charm {
    name = "alertmanager-k8s"
    channel = "stable"
  }
  units = 1
}

resource "juju_application" "prometheus" {
  name = "prometheus"
  trust = true

  model = var.cos_model_name
  charm {
    name = "prometheus-k8s"
    channel = "stable"
  }
  units = 1
}

resource "juju_application" "grafana" {
  name = "grafana"
  trust = true

  model = var.cos_model_name
  charm {
    name = "grafana-k8s"
    channel = "stable"
  }
  units = 1
}

resource "juju_application" "loki" {
  name = "loki"
  trust = true

  model = var.cos_model_name
  charm {
    name = "loki-k8s"
    channel = "stable"
  }
  units = 1
}


/////////////////////////////////////////////////////////////
// Integrations
/////////////////////////////////////////////////////////////


//- [traefik:ingress-per-unit, prometheus:ingress]
resource "juju_integration" "traefik_prometheus" {
  model = var.cos_model_name

  application {
    name     = juju_application.traefik.name
    endpoint = "ingress-per-unit"
  }

  application {
    name     = juju_application.prometheus.name
    endpoint = "ingress"
  }

  depends_on = [
    juju_application.traefik,
    juju_application.prometheus,
    juju_application.alertmanager,
    juju_application.grafana,
    juju_application.loki 
  ]
}

//- [traefik:ingress-per-unit, loki:ingress]
resource "juju_integration" "traefik_loki" {
  model = var.cos_model_name

  application {
    name     = juju_application.traefik.name
    endpoint = "ingress-per-unit"
  }

  application {
    name     = juju_application.loki.name
    endpoint = "ingress"
  }
}

//- [traefik:traefik-route, grafana:ingress]
resource "juju_integration" "traefik_grafana" {
  model = var.cos_model_name

  application {
    name     = juju_application.traefik.name
    endpoint = "traefik-route"
  }

  application {
    name     = juju_application.grafana.name
    endpoint = "ingress"
  }
}

//- [traefik:ingress, alertmanager:ingress]
resource "juju_integration" "traefik_alertmanager" {
  model = var.cos_model_name

  application {
    name     = juju_application.traefik.name
    endpoint = "ingress"
  }

  application {
    name     = juju_application.alertmanager.name
    endpoint = "ingress"
  }
}

//- [prometheus:alertmanager, alertmanager:alerting]
resource "juju_integration" "prometheus_alertmanager" {
  model = var.cos_model_name

  application {
    name     = juju_application.prometheus.name
    endpoint = "alertmanager"
  }

  application {
    name     = juju_application.alertmanager.name
    endpoint = "alerting"
  }
}

//- [prometheus:alertmanager, loki:alerting]
resource "juju_integration" "loki_alertmanager" {
  model = var.cos_model_name

  application {
    name     = juju_application.loki.name
    endpoint = "alertmanager"
  }

  application {
    name     = juju_application.alertmanager.name
    endpoint = "alerting"
  }
}

//- [grafana:grafana-source, prometheus:grafana-source]
resource "juju_integration" "grafana_prometheus" {
  model = var.cos_model_name

  application {
    name     = juju_application.grafana.name
    endpoint = "grafana-source"
  }

  application {
    name     = juju_application.prometheus.name
    endpoint = "grafana-source"
  }
}

//- [grafana:grafana-source, loki:grafana-source]
resource "juju_integration" "grafana_loki" {
  model = var.cos_model_name

  application {
    name     = juju_application.grafana.name
    endpoint = "grafana-source"
  }

  application {
    name     = juju_application.loki.name
    endpoint = "grafana-source"
  }
}

//- [grafana:grafana-source, alertmanager:grafana-source]
resource "juju_integration" "grafana_alertmanager" {
  model = var.cos_model_name

  application {
    name     = juju_application.grafana.name
    endpoint = "grafana-source"
  }

  application {
    name     = juju_application.alertmanager.name
    endpoint = "grafana-source"
  }
}

/////////////////////////////////////////////////////////////
// COS Monitoring
/////////////////////////////////////////////////////////////

//- [prometheus:metrics-endpoint, traefik:metrics-endpoint]
//- [prometheus:metrics-endpoint, alertmanager:self-metrics-endpoint]
//- [prometheus:metrics-endpoint, loki:metrics-endpoint]
//- [prometheus:metrics-endpoint, grafana:metrics-endpoint]
resource "juju_integration" "grafana_metrics" {
  model = var.cos_model_name
  for_each = {
    "${juju_application.traefik.name}" = {
      name     = juju_application.traefik.name
      endpoint = "metrics-endpoint"
    },
    rel2 = {
      name     = juju_application.alertmanager.name
      endpoint = "self-metrics-endpoint"
    },
    rel3 = {
      name     = juju_application.loki.name
      endpoint = "metrics-endpoint"
    },
    rel4 = {
      name     = juju_application.grafana.name
      endpoint = "metrics-endpoint"
    }
  }

  application {
    name     = juju_application.prometheus.name
    endpoint = "metrics-endpoint"
  }

  application {
    name     = each.value.name
    endpoint = each.value.endpoint
  }

  depends_on = [
    juju_application.traefik,
    juju_application.prometheus,
    juju_application.alertmanager,
    juju_application.grafana,
    juju_application.loki 
  ]
}

# - [grafana:grafana-dashboard, loki:grafana-dashboard]
# - [grafana:grafana-dashboard, prometheus:grafana-dashboard]
# - [grafana:grafana-dashboard, alertmanager:grafana-dashboard]
resource "juju_integration" "grafana_dashboard" {
  model = var.cos_model_name
  for_each = {
    rel1 = {
      name = juju_application.loki.name
    },
    rel2 = {
      name = juju_application.alertmanager.name
    },
    rel3 = {
      name = juju_application.prometheus.name
    }
  }

  application {
    name     = juju_application.grafana.name
    endpoint = "grafana-dashboard"
  }

  application {
    name     = each.value.name
    endpoint = "grafana-dashboard"
  }
}


/////////////////////////////////////////////////////////////
// COS Offerings
/////////////////////////////////////////////////////////////

resource "juju_offer" "alertmanager-karma-dashboard" {
  model            = var.cos_model_name
  application_name = juju_application.alertmanager.name
  endpoint         = "karma-dashboard"
}

resource "juju_offer" "grafana-dashboard" {
  model            = var.cos_model_name
  application_name = juju_application.grafana.name
  endpoint         = "grafana-dashboard"
}

resource "juju_offer" "loki-logging" {
  model            = var.cos_model_name
  application_name = juju_application.loki.name
  endpoint         = "logging"
}

resource "juju_offer" "prometheus-scrape" {
  model            = var.cos_model_name
  application_name = juju_application.prometheus.name
  endpoint         = "metrics-endpoint"
}

resource "juju_offer" "prometheus-receive-remote-write" {
  model            = var.cos_model_name
  application_name = juju_application.prometheus.name
  endpoint         = "receive-remote-write"
}

/////////////////////////////////////////////////////////////
// OUTPUTS
/////////////////////////////////////////////////////////////

output "cos_model_name" {
  description = "COS model name"
  value = var.cos_model_name
}

output "alertmanager-offering" {
  description = "Alertmanager offering"
  value = juju_offer.alertmanager-karma-dashboard.url
}

output "grafana-offering" {
  description = "Grafana offering"
  value = juju_offer.grafana-dashboard.url
}

output "loki-offering" {
  description = "Loki offering"
  value = juju_offer.loki-logging.url
}

output "prometheus-scrape-offering" {
  description = "Prometheus scrape offering"
  value = juju_offer.prometheus-scrape.url
}

output "prometheus-rw-offering" {
  description = "Prometheus receive remote write offering"
  value = juju_offer.prometheus-receive-remote-write.url
}