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
