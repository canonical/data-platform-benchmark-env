output "controller_name" {
  description = "Controller name chosen"
  value = var.controller_name
}

output "controller_info" {
    description = ""
    value = {
        name = var.controller_name
        api_endpoints = join(",", yamldecode(data.local_file.controller_info.content)["controllers"][var.controller_name]["api-endpoints"])
        ca_cert = yamldecode(data.local_file.controller_info.content)["controllers"][var.controller_name]["ca-cert"]
        username = yamldecode(data.local_file.account_info.content)["controllers"][var.controller_name]["user"]
        password = yamldecode(data.local_file.account_info.content)["controllers"][var.controller_name]["password"]
    }
}

output "private_subnet_id" {
  description = "ID of the private subnet created"
  value = aws_subnet.private_cidr.id
}