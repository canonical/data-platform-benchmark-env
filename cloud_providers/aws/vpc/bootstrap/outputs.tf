output "controller_name" {
  description = "Controller name chosen"
  value       = var.controller_name
}

output "juju_build_with_debug_symbols" {
  description = "Build with debug symbols"
  value       = local.build_debug
}

output "controller_info" {
  description = "Controller info"
  value = {
    name          = var.controller_name
    api_endpoints = data.external.controller_api_endpoints_without_fan_networking.result["output"]
    ca_cert       = yamldecode(data.external.juju_controller_info.result["output"])[var.controller_name]["details"]["ca-cert"]
    username      = yamldecode(data.external.juju_controller_info.result["output"])[var.controller_name]["account"]["user"]
    password      = yamldecode(data.external.juju_controller_info.result["output"])[var.controller_name]["account"]["password"]
  }
}
