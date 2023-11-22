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
  }
}

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

variable "vpc" {
  type = object({
    name   = string
    region = string
    az     = string
    cidr   = string
  })
  default = {
    name   = "test-vpc"
    region = "us-east-1"
    az     = "us-east-1a"
    cidr   = "192.168.234.0/23"
  }
}

variable "private_subnet_id" {
  description = "ID of the subnet where the instance will be launched"
}

variable "key_name" {
  description = "Name of the SSH key pair to associate with the instance"
}

variable "ami_id" {
  description = "ID of the AMI to use for the instance"
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

resource "aws_security_group" "cos_microk8s_sg" {
  name        = "cos-microk8s-sg"
  description = "cos-microk8s-sg"

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
}

resource "aws_network_interface" "microk8s_nic" {

  subnet_id = var.private_subnet_id
  private_ip_list = var.microk8s_ips
  private_ip_list_enabled = true
  security_groups = [aws_security_group.cos_microk8s_sg.id]
}


resource "aws_instance" "microk8s_vm" {
  ami           = var.ami_id
  instance_type = var.instance_type
  network_interface {
     network_interface_id = "${aws_network_interface.microk8s_nic.id}"
     device_index = 0
  }
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.cos_microk8s_sg.id]

  depends_on = [aws_security_group.cos_microk8s_sg, aws_network_interface.microk8s_nic]
}

resource "null_resource" "deploy_microk8s" {

  provisioner "local-exec" {
    command = "juju add-machine ssh:ubuntu@${aws_instance.microk8s_nic.microk8s_ip_list.0} --model ${var.controller_name}"
    
    
    
    bootstrap aws ${var.controller_name} --credential aws_tf_creds  --model-default vpc-id=${var.vpc_id} --model-default vpc-id-force=true --config vpc-id=${var.vpc_id} --config vpc-id-force=true --constraints 'instance-type=${var.constraints.instance_type} root-disk=${var.constraints.root_disk_size}' --to subnet=${var.private_cidr}"
  }

#  provisioner "local-exec" {
#    when = destroy
#    command = "juju destroy-controller --yes --destroy-storage --destroy-all-models --force --no-wait ${self.triggers.controller_name}"
#  }

  provisioner "local-exec" {
    when = destroy
    command = "juju remove-credential aws aws_tf_creds --client"
  }
  depends_on = [aws_instance.microk8s_vm]
}

resource "null_resource" "deploy_metallb" {

  provisioner "local-exec" {
    command = "juju bootstrap aws ${var.controller_name} --credential aws_tf_creds  --model-default vpc-id=${var.vpc_id} --model-default vpc-id-force=true --config vpc-id=${var.vpc_id} --config vpc-id-force=true --constraints 'instance-type=${var.constraints.instance_type} root-disk=${var.constraints.root_disk_size}' --to subnet=${var.private_cidr}"
  }

#  provisioner "local-exec" {
#    when = destroy
#    command = "juju destroy-controller --yes --destroy-storage --destroy-all-models --force --no-wait ${self.triggers.controller_name}"
#  }

  provisioner "local-exec" {
    when = destroy
    command = "juju remove-credential aws aws_tf_creds --client"
  }
  depends_on = [aws_instance.microk8s_vm]
}
