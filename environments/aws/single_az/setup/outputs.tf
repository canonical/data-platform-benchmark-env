output "jumphost_elastic_ip" {
  description = "The IPv4 address of the instance."
  value       = aws_instance.instance.public_ip
}

output "private_key_file" {
  value     = tls_private_key.generated_key_path.filename
}

output "vpc_id" {
  description = "The vpc id."
  value       = aws_vpc.single_az_vpc.id
}
