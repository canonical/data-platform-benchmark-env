terraform {
  required_version = "~> 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = var.vpc.region
}


// --------------------------------------------------------------------------------------
//           Key build
// --------------------------------------------------------------------------------------

resource "tls_private_key" "user_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.user_key.public_key_openssh
}

// --------------------------------------------------------------------------------------
//           VPC build   
// --------------------------------------------------------------------------------------

resource "aws_vpc" "single_az_vpc" {
  cidr_block = var.vpc.cidr
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc.name
  }
}

// --------------------------------------------------------------------------------------
//           Public subnet build
// --------------------------------------------------------------------------------------

resource "aws_internet_gateway" "single_az_igw" {
  vpc_id = aws_vpc.single_az_vpc.id
}

resource "aws_subnet" "public_cidr" {
  vpc_id            = aws_vpc.single_az_vpc.id
  cidr_block        = var.public_cidr.cidr
  availability_zone = var.vpc.az

  tags = {
    Name = var.public_cidr.name
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.single_az_vpc.id

  route { 
    cidr_block        = "0.0.0.0/0"
    gateway_id        = aws_internet_gateway.single_az_igw.id
  }
  route {
    cidr_block = var.vpc.cidr 
    gateway_id = "local"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id = aws_subnet.public_cidr.id
  route_table_id = aws_route_table.public_rt.id
}


// --------------------------------------------------------------------------------------
//           Private subnet build
// --------------------------------------------------------------------------------------

resource "aws_eip" "jumphost_nat_eip" {
  domain                    = "vpc"
  instance = aws_instance.jumphost.id
}


resource "aws_nat_gateway" "single_az_nat" {
  allocation_id = aws_eip.example.id
  subnet_id     = aws_subnet.private_cidr.id
  connectivity_type = "public"

  depends_on = [aws_internet_gateway.single_az_igw]
}

resource "aws_subnet" "private_cidr" {
  vpc_id            = aws_vpc.single_az_vpc.id
  cidr_block        = var.private_cidr.cidr
  availability_zone = var.vpc.az

  tags = {
    Name = var.private_cidr.name
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.single_az_vpc.id

  route {
    cidr_block        = "0.0.0.0/0"
    gateway_id        = aws_nat_gateway.single_az_nat.id
  }
  route {
    cidr_block = var.vpc.cidr
    gateway_id = "local"
  }
}

resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id = aws_subnet.private_cidr.id
  route_table_id = aws_route_table.private_rt.id
}


// --------------------------------------------------------------------------------------
//           Jumphost build
// --------------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_network_interface" "jumphost_nic" {
  subnet_id   = aws_subnet.public_cidr.id

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_instance" "jumphost" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name

  network_interface {
    network_interface_id = aws_network_interface.jumphost_nic.id
    device_index         = 0
  }

  tags = {
    Name = "jumphost"
  }
}

resource "aws_eip" "jumphost_elastic_ip" {
  domain                    = "vpc"
  instance = aws_instance.jumphost.id
}

