output "vpc" {
  description = "VPC object copied from variable to the next stage"
  value = var.vpc
}

output "private_cidr" {
  description = "Private CIDR copied from variable to the next stage"
  value = var.private_cidr.cidr
}

output "public_cidr" {
  description = "Public CIDR copied from variable to the next stage"
  value = var.public_cidr.cidr
}

output "jumphost_elastic_ip" {
  description = "The IPv4 address of the instance."
  value       = aws_eip.jumphost_elastic_ip.public_ip
}

output "private_key_file" {
  value     = local_sensitive_file.generated_key_path.filename
}

output "vpc_id" {
  description = "The vpc id."
  value       = aws_vpc.single_az_vpc.id
}
