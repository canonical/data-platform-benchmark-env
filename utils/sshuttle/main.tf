terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

resource "terraform_data" "sshuttle" {

  provisioner "local-exec" {
    command = "sudo sshuttle -D --pidfile=/tmp/sshuttle.pid -r ubuntu@${var.jumphost_ip} ${var.subnet} -e 'ssh -o StrictHostKeyChecking=no -i ${var.private_key_filepath}'"
  }

  provisioner "local-exec" {
    when = destroy
    command = "sudo kill -9 $(cat /tmp/sshuttle.pid)"
  }
}
