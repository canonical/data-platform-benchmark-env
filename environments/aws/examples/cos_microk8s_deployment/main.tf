terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    local = {
      source = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.1"
    }
    /*
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
    */
  }
}

/*
provider "aws" {
  region = var.vpc.region
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}

variable "AWS_ACCESS_KEY" {
    type      = string
    sensitive = true
}

variable "AWS_SECRET_KEY" {
    type      = string
    sensitive = true
}
*/

variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  description = "ID of the subnet where the instance will be launched"
}

variable "model_name" {
  description = "Name of the model to create"
  default = "cos-microk8s"
}

variable "aws_key_name" {
  description = "Name of the SSH key pair to associate with the instance"
}

variable "key_path" {
  description = "Path to the SSH private key"
}

variable "ami_id" {
  description = "ID of the AMI to use for the instance"
}

variable "cos_microk8s_bundle" {
  type = string
}

variable "cos_microk8s_overlay" {
  type = string
}

variable "space_name" {
  type = string
  default = "internal-space"
}

variable "cos_model_name" {
  type = string
  default = "cos"
}

variable "microk8s_charm_channel" {
  type = string
  default = "1.28/stable"
}

variable "instance_type" {
  description = "Type of instance to launch"
  default = "t2.xlarge"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  default = "192.168.234.0/23"
}

variable "microk8s_ips" {
  type = list(string)
  default = ["192.168.235.201", "192.168.235.202", "192.168.235.203"]
}

variable "juju_pub_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "cos_microk8s_kubeconfig" {
  default = "~/.kube/tf_cos_terraform_config"
}

variable "microk8s_cloud_name" {
  default = "cos-k8s"
}

variable "metallb_channel_name" {
  default = "latest/edge"
}

variable "metallb_model_name" {
  default = "metallb-microk8s"
}

resource "aws_security_group" "cos_microk8s_sg" {
  name        = "cos-microk8s-sg"
  description = "cos-microk8s-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 10000
    to_port     = 60000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_network_interface" "microk8s_nic" {

  subnet_id = var.private_subnet_id
  private_ip_list = var.microk8s_ips
  private_ip_list_enabled = true
  security_groups = [aws_security_group.cos_microk8s_sg.id]

  depends_on = [aws_security_group.cos_microk8s_sg, aws_network_interface.microk8s_nic]
}


resource "aws_instance" "microk8s_vm" {
  ami           = var.ami_id
  instance_type = var.instance_type
  network_interface {
     network_interface_id = "${aws_network_interface.microk8s_nic.id}"
     device_index = 0
  }
  key_name      = var.aws_key_name

  depends_on = [aws_security_group.cos_microk8s_sg, aws_network_interface.microk8s_nic]
}

data "local_file" "juju_pub_key" {
  filename = pathexpand(var.juju_pub_key)

  depends_on = [aws_instance.microk8s_vm]
}

data "local_file" "ssh_known_hosts" {
  filename = pathexpand("~/.ssh/known_hosts")

  depends_on = [aws_instance.microk8s_vm]
}

resource "null_resource" "clean_known_hosts" {

#  # Prepare machine: add the juju key so we do not have a prompt with SSH
#  provisioner "local-exec" {
#    command = "ssh -i ${var.key_path} -o StrictHostKeyChecking=no ubuntu@${aws_network_interface.microk8s_nic.private_ip_list.0} \"echo '${data.local_file.juju_pub_key.content}' >> /home/ubuntu/.ssh/authorized_keys\""
#  }

#  provisioner "local-exec" {
#    command = "ssh-keygen -R ${aws_network_interface.microk8s_nic.private_ip_list.0} || true"
##      "ssh-keyscan -H ${aws_network_interface.microk8s_nic.private_ip_list.0} >> ${data.local_file.ssh_known_hosts.filename}"
##    EOT
#  }

  # Disable fan networking
  provisioner "local-exec" {
    command = "ssh-keygen -R ${aws_network_interface.microk8s_nic.private_ip_list.0} || true; for i in {0..5}; do sleep 60s; ssh -i ${var.key_path} -o StrictHostKeyChecking=no ubuntu@${aws_network_interface.microk8s_nic.private_ip_list.0} exit || true; done"
  }

  depends_on = [aws_instance.microk8s_vm, data.local_file.juju_pub_key]
}



resource "null_resource" "deploy_microk8s" {

  # Add the machine
  provisioner "local-exec" {
    command = <<-EOT
    juju add-machine ssh:ubuntu@${aws_network_interface.microk8s_nic.private_ip_list.0} --model ${var.model_name} --private-key ${var.key_path};
    juju ssh --model ${var.model_name} 0 sudo fanctl down -a;
    juju deploy microk8s --channel=${var.microk8s_charm_channel} --config hostpath_storage=true --model ${var.model_name} --bind ${var.space_name} --to=0;
    juju-wait --model ${var.model_name}
    EOT
  }
  depends_on = [null_resource.clean_known_hosts]

}



resource "null_resource" "prepare_microk8s_cloud" {

  # Finally, load the new microk8s as another cloud in juju
  provisioner "local-exec" {
    command = <<EOT
    juju ssh --model ${var.model_name} microk8s/0 sudo microk8s config > ${var.cos_microk8s_kubeconfig}
    kubectl config --kubeconfig ${var.cos_microk8s_kubeconfig} view --raw | juju add-k8s --client --controller ${var.microk8s_cloud_name}
    EOT
  }

  depends_on = [null_resource.deploy_microk8s]
}


locals {
  last_ip_value = element(aws_network_interface.microk8s_nic.private_ip_list, length(aws_network_interface.microk8s_nic.private_ip_list)-1)
}

resource "null_resource" "deploy_metallb" {

  # Add the model
  provisioner "local-exec" {
    command = "juju add-model ${var.metallb_model_name} ${var.microk8s_cloud_name}"
  }

  provisioner "local-exec" {
    command = "juju deploy metallb --channel=${var.metallb_channel_name} --model ${var.metallb_model_name} --config iprange=${aws_network_interface.microk8s_nic.private_ip_list.1}-${local.last_ip_value}"
  }

  provisioner "local-exec" {
    command = "juju-wait --model ${var.metallb_model_name}"
  }
/*
  provisioner "local-exec" {
    when = destroy
    command = "juju destroy-model --force --no-wait --destroy-storage ${var.metallb_model_name}"
  }
*/
  depends_on = [null_resource.deploy_microk8s]
}



resource "null_resource" "deploy_cos" {

  # Add the model
  provisioner "local-exec" {
    command = "juju add-model ${var.cos_model_name} ${var.microk8s_cloud_name}"
  }

  provisioner "local-exec" {
    command = "juju deploy ${var.cos_microk8s_bundle} --model ${var.cos_model_name} --overlay ${var.cos_microk8s_overlay} --trust"
  }

  provisioner "local-exec" {
    command = "juju-wait --model ${var.cos_model_name}"
  }

/*
  provisioner "local-exec" {
    when = destroy
    command = "juju destroy-model --force --no-wait --destroy-storage ${var.cos_model_name}"
  }
*/

  depends_on = [null_resource.deploy_metallb]
}
