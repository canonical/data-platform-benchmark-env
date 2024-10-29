terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = ">= 4.0.4"
    }
    local = {
      source = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
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

resource "local_sensitive_file" "generated_key_path" {
  content     = tls_private_key.user_key.private_key_openssh
  filename    = "${path.cwd}/${var.vpc.name}-private.key"
}

resource "local_sensitive_file" "generated_public_key_path" {
  content     = tls_private_key.user_key.public_key_openssh
  filename    = "${path.cwd}/${var.vpc.name}-public.key"
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

  tags = {
    Name = "igw-${var.vpc.name}-${var.public_cidr.name}"
  }
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
  tags = {
    Name = "public-rt-${var.vpc.name}-${var.public_cidr.name}"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id = aws_subnet.public_cidr.id
  route_table_id = aws_route_table.public_rt.id
}


// --------------------------------------------------------------------------------------
//           Private subnet(s) build
// --------------------------------------------------------------------------------------

resource "aws_eip" "jumphost_nat_eip" {
  count = "${length(var.private_cidrs)}"

  tags = {
    Name = "igw-${var.vpc.name}-${var.public_cidr.name}"
  }

  depends_on = [aws_internet_gateway.single_az_igw]
}


resource "aws_nat_gateway" "single_az_nat" {
  count = "${length(var.private_cidrs)}"

  allocation_id = aws_eip.jumphost_nat_eip[count.index].id
  subnet_id     = aws_subnet.public_cidr.id
  connectivity_type = "public"

  tags = {
    Name = "nat-${var.vpc.name}-${keys(var.private_cidrs)[count.index]}"
  }

  depends_on = [aws_eip.jumphost_nat_eip]
}

resource "aws_subnet" "private_cidr" {
  count = "${length(var.private_cidrs)}"

  vpc_id            = aws_vpc.single_az_vpc.id
  cidr_block        = "${values(var.private_cidrs)[count.index].cidr}"
  availability_zone = var.vpc.az

  tags = {
    Name = "${keys(var.private_cidrs)[count.index]}"
  }
}

resource "aws_route_table" "private_rt" {
  count = "${length(var.private_cidrs)}"

  vpc_id = aws_vpc.single_az_vpc.id

  route {
    cidr_block        = "0.0.0.0/0"
    gateway_id        = aws_nat_gateway.single_az_nat[count.index].id
  }
  route {
    cidr_block = var.vpc.cidr
    gateway_id = "local"
  }
  tags = {
    Name = "private-rt-${var.vpc.name}-${keys(var.private_cidrs)[count.index]}"
  }
}

resource "aws_route_table_association" "private_rt_assoc" {
  count = "${length(var.private_cidrs)}"

  subnet_id = aws_subnet.private_cidr[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
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

resource "aws_security_group" "sg_jumphost" {
  description = "SSH access to the jumphost"
  vpc_id      = aws_vpc.single_az_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "${var.vpc.name}-jumphost-sg"
  }
}

resource "aws_instance" "jumphost" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name
  subnet_id   = aws_subnet.public_cidr.id
  vpc_security_group_ids = [aws_security_group.sg_jumphost.id]

  tags = {
    Name = "${var.vpc.name}-jumphost"
  }
}

resource "aws_eip" "jumphost_elastic_ip" {
  domain                    = "vpc"
  instance = aws_instance.jumphost.id
  depends_on = [aws_instance.jumphost]
}
