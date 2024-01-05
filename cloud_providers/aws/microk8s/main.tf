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

resource "aws_security_group" "microk8s_sg" {
  name        = var.security_group_name
  description = "Security group managed by TF and exposes all node ports"
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

// 
resource "aws_network_interface" "microk8s_nic" {

  subnet_id = var.private_subnet_id
  private_ip_list = var.microk8s_ips
  private_ip_list_enabled = true
  security_groups = [aws_security_group.microk8s_sg.id]

  depends_on = [aws_security_group.microk8s_sg, aws_network_interface.microk8s_nic]
}


resource "aws_instance" "microk8s_vm" {
  ami           = var.ami_id
  instance_type = var.instance_type
  network_interface {
     network_interface_id = "${aws_network_interface.microk8s_nic.id}"
     device_index = 0
  }
  key_name      = var.aws_key_name
  root_block_device {
     volume_size   = var.root_disk_size_in_gb
  }

  depends_on = [aws_security_group.microk8s_sg, aws_network_interface.microk8s_nic]
}


# For some reason, this file is getting deleted at destroy time.
resource "local_file" "id_rsa_pub_key"  {
  filename = "/tmp/id_rsa_temp123.pub"
  content  = file(pathexpand(var.public_key_path))
}

resource "null_resource" "wait_microk8s_vm" {
  provisioner "local-exec" {
    command = <<-EOT
    ssh-keygen -R ${aws_network_interface.microk8s_nic.private_ip_list.0} || true;
    for i in {0..5}; do 
      sleep 60s;
      ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_network_interface.microk8s_nic.private_ip_list.0} exit;
      if [[ $? -eq 0 ]]; then
        break;
      fi;
    done;
    ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_network_interface.microk8s_nic.private_ip_list.0} "echo '${local_file.id_rsa_pub_key.content}' >> ~/.ssh/authorized_keys"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [aws_instance.microk8s_vm]
}