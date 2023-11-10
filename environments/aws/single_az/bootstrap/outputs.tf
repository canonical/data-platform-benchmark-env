output "controller_name" {
  description = "Controller name chosen"
  value = var.controller_name
}

output "controller_info" {
    description = ""
    value = {
        name = var.controller_name
        api_endpoints = join(",", yamldecode(file(data.local_file.controller_info.filename))["controllers"][var.controller_name]["api-endpoints"])
        ca_cert = yamldecode(file(data.local_file.controller_info.filename))["controllers"][var.controller_name]["ca-cert"]
        username = yamldecode(file(data.local_file.account_info.filename))["controllers"][var.controller_name]["user"]
        password = yamldecode(file(data.local_file.account_info.filename))["controllers"][var.controller_name]["password"]
    }
}


/*
output "controller_info" {
    description = ""
    value = {
        name = var.controller_name
        api_endpoints = join(",", yamldecode(file(pathexpand("~/.local/share/juju/controllers.yaml")))["controllers"][var.controller_name]["api-endpoints"])
        ca_cert = yamldecode(file(pathexpand("~/.local/share/juju/controllers.yaml")))["controllers"][var.controller_name]["ca-cert"]
        username = yamldecode(file(pathexpand("~/.local/share/juju/accounts.yaml")))["controllers"][var.controller_name]["user"]
        password = yamldecode(file(pathexpand("~/.local/share/juju/accounts.yaml")))["controllers"][var.controller_name]["password"]        
    }
    depends_on = [null_resource.bootstrap]
}
*/