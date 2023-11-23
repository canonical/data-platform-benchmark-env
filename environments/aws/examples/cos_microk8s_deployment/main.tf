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
    juju = {
      source  = "juju/juju"
      version = ">= 0.3.1"
    }
    external = {
      source = "hashicorp/external"
      version = ">=2.3.2"
    }
  }
}

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

variable "aws_private_key_path" {
  description = "Path to the AWS SSH private key"
}

variable "private_key_path" {
  description = "Path to the SSH private key"
}

variable "public_key_path" {
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

variable "controller_name" {
  type = string
  description = "Name of the controller"
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


resource "local_file" "id_rsa_pub_key"  {
  filename = var.public_key_path
  content  = file(pathexpand(var.public_key_path))
}

resource "null_resource" "wait_microk8s_vm" {
  provisioner "local-exec" {
    command = <<-EOT
    ssh-keygen -R ${aws_network_interface.microk8s_nic.private_ip_list.0} || true;
    for i in {0..5}; do 
      sleep 60s;
      ssh -i ${var.aws_private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_network_interface.microk8s_nic.private_ip_list.0} exit;
      if [[ $? -eq 0 ]]; then
        break;
      fi;
    done;
    ssh -i ${var.aws_private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_network_interface.microk8s_nic.private_ip_list.0} "echo '${local_file.id_rsa_pub_key.content}' >> ~/.ssh/authorized_keys"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [aws_instance.microk8s_vm]
}

resource "juju_machine" "microk8s_vm" {
  model = var.model_name
  private_key_file = var.private_key_path
  public_key_file = var.public_key_path

  ssh_address = "ubuntu@${aws_network_interface.microk8s_nic.private_ip_list.0}"

  depends_on = [null_resource.wait_microk8s_vm]
  #  depends_on = [null_resource.clean_known_hosts]
}

resource "juju_application" "microk8s" {
  name = "microk8s"
  model = var.model_name
  charm {
    name = "microk8s"
    channel = var.microk8s_charm_channel
  }
  units = 1
  placement = "${juju_machine.microk8s_vm.machine_id}"

  config = {
    hostpath_storage = true
  }

  depends_on = [juju_machine.microk8s_vm]
}

resource "null_resource" "juju_wait_microk8s_app" {
  provisioner "local-exec" {
    command = "juju-wait --model ${var.model_name}"
  }
  depends_on = [juju_application.microk8s]

}

resource "null_resource" "save_kubeconfig" {

  # Finally, load the new microk8s as another cloud in juju
  provisioner "local-exec" {
    command = "ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_network_interface.microk8s_nic.private_ip_list.0} 'sudo microk8s config' > ${pathexpand(var.cos_microk8s_kubeconfig)}"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [null_resource.juju_wait_microk8s_app]
}

resource "null_resource" "prepare_microk8s_cloud" {

  provisioner "local-exec" {
    command = "kubectl config --kubeconfig ${var.cos_microk8s_kubeconfig} view --raw | juju add-k8s ${var.microk8s_cloud_name} --client --controller ${var.controller_name}"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [null_resource.save_kubeconfig]
}

resource "juju_model" "metallb_model" {
  name = var.metallb_model_name

  cloud {
    name   = var.microk8s_cloud_name
  }
  # juju add-k8s adds kubeconfig as credentials with the same name as the cloud
  credential = var.microk8s_cloud_name

  depends_on = [null_resource.prepare_microk8s_cloud]

  # TODO: remove this workaround :)
  # We need a place to remove the credentials from microk8s cluster once we start the destroy process
  # This is the first model to be created and the only place where we keep the microk8s_cloud_name as a variable
  # in the "self" object.
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
    juju remove-cloud ${self.cloud.name} --client;
    juju remove-credential ${self.cloud.name} ${self.cloud.name} --client
    EOT
  }

}

resource "juju_model" "cos_model" {
  name = var.cos_model_name

  cloud {
    name       = var.microk8s_cloud_name
  }
  # juju add-k8s adds kubeconfig as credentials with the same name as the cloud
  credential = var.microk8s_cloud_name

  depends_on = [null_resource.prepare_microk8s_cloud]
}

locals {
  last_ip_value = element(aws_network_interface.microk8s_nic.private_ip_list, length(aws_network_interface.microk8s_nic.private_ip_list)-1)
}

resource "juju_application" "metallb" {

  model = var.metallb_model_name
  charm {
    name = "metallb"
    channel = var.metallb_channel_name
  }
  units = 1
  config = {
    iprange = "${aws_network_interface.microk8s_nic.private_ip_list.1}-${local.last_ip_value}"
  }
  depends_on = [juju_model.metallb_model]

}

resource "null_resource" "juju_wait_metallb_app" {
  provisioner "local-exec" {
    command = "juju-wait --model ${var.metallb_model_name}"
  }

  depends_on = [juju_application.metallb]
}

# Unfortunately, deploying entire bundles with overlay is not yet available
resource "null_resource" "deploy_cos_bundle" {
  provisioner "local-exec" {
    command = <<-EOT
    juju deploy ${var.cos_microk8s_bundle} --model ${var.cos_model_name} --overlay ${var.cos_microk8s_overlay} --trust;
    juju-wait --model ${var.cos_model_name}
    EOT
  }

  depends_on = [null_resource.juju_wait_metallb_app]
}