terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

resource "null_resource" "validate_sudo_not_need_password" {
  provisioner "local-exec" {
    command = <<-EOT
    if [ ! $(sudo -n true 2>/dev/null) ]; then 
      echo "Sudo requires password!!! Please enter it before proceeding!";
      exit 1;
    fi
    EOT    
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
  depends_on = [null_resource.validate_sudo_not_need_password]
}
