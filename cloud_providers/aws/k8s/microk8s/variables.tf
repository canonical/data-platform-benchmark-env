variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  description = "ID of the subnet where the instance will be launched"
}

variable "security_group_name" {
  description = "Name of the security group to associate with the instance"
  default = "microk8s-sg"
}

variable "aws_key_name" {
  description = "Name of the SSH key pair to associate with the instance"
}

variable "aws_private_key_path" {
  description = "Path to the AWS SSH private key"
  type = string
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

variable "instance_type" {
  description = "Type of instance to launch"
  default = "t2.xlarge"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  // default = "192.168.234.0/23"
}

variable "microk8s_ips" {
  type = list(string)
  // default = ["192.168.235.201", "192.168.235.202", "192.168.235.203"]
}

variable "juju_pub_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "root_disk_size_in_gb" {
  type = number
  default = 600  # 600G of disk
}