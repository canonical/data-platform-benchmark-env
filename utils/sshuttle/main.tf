terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source = "hashicorp/local"
      version = ">= 2.4.0"
    }
    external = {
      source = "hashicorp/external"
      version = ">=2.3.2"
    }
  }

}

resource "terraform_data" "sshuttle" {
  input = "/tmp/sshuttle.pid"

  provisioner "local-exec" {
    command = <<-EOT
    sudo -n true 2>/dev/null;
    if [ $? -ne 0 ]; then
      echo "sshuttle demands SUDO: make sure the password has been entered, e.g. on 'sudo true'";
      exit 1
    fi
    if test -f /tmp/sshuttle.pid; then
      sudo kill -9 $(cat /tmp/sshuttle.pid)
    fi
    sudo sshuttle -D --pidfile=/tmp/sshuttle.pid -r ubuntu@${var.jumphost_ip} ${var.subnet} -e 'ssh -o StrictHostKeyChecking=no -i ${var.private_key_filepath}'
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
    if [ $? -ne 0 ]; then
      exit 1
    fi
    sudo kill -9 $(cat /tmp/sshuttle.pid)
    EOT
  }

  # lifecycle {
  #   // We want to create a new one before destroying the old value
  #   // The main reason is to doublecheck we have sudo access before stopping the sshuttle
  #   create_before_destroy = true
  # }
  // depends_on = [null_resource.validate_sudo_not_need_password]
}
