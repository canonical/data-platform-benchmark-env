output "controller_name" {
  description = "Controller name chosen"
  value = var.controller_name
}

output "controller_info" {
  description = "Controller info"
  value = {
      name = var.controller_name
      api_endpoints = join(",", yamldecode(data.external.juju_controller_info.result["output"])[var.controller_name]["details"]["api-endpoints"])
      ca_cert = yamldecode(data.external.juju_controller_info.result["output"])[var.controller_name]["details"]["ca-cert"]
      username = yamldecode(data.external.juju_controller_info.result["output"])[var.controller_name]["account"]["user"]
      password = yamldecode(data.external.juju_controller_info.result["output"])[var.controller_name]["account"]["password"]        
  }
}