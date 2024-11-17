output "id_rsa_pub_key" {
  value = local_file.id_rsa_pub_key.filename
}

output "microk8s_private_ip" {
  value = aws_network_interface.microk8s_nic.private_ip_list[0]
}