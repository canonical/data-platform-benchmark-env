output "jumphost_elastic_ip" {
  description = "The IPv4 address of the instance."
  value       = aws_instance.instance.public_ip
}

output "private_key" {
  value     = tls_private_key.user_key.private_key_pem
  sensitive = true
}
