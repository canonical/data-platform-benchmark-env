// Adds a machine on an existing model and installs microk8s

resource "juju_machine" "microk8s_machine" {
    model       = var.model_name
    base        = var.base_image
    constraints = "instance-type=${var.constraints.instance_type} spaces=${join(",", var.constraints.spaces)}"
}

resource "terraform_data" "microk8s_deploy" {
    provisioner "local-exec" {
        command = "juju deploy microk8s --channel=${var.channel} --config hostpath_storage=${var.hostpath_storage} --bind '${join(",", var.spaces)}'"
    }
    depends-on = ["microk8s_machine"]
}

resource "terraform_data" "microk8s_dns" {
    provisioner "local-exec" {
        command = (
            var.dns.enable ? 
            "juju run --unit microk8s/0 'sudo microk8s enable dns:${var.dns.server}'" :
            "/bin/true"
        )
    }
}