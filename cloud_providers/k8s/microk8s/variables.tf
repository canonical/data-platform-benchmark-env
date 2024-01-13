variable "model_name" {
  description = "Name of the model to create"
  type = string
  // default = "cos-microk8s"
}

variable "hostpath_storage_enabled" {
  description = "Enable hostpath storage"
  default = true
}

variable "private_key_path" {
  description = "Path to the SSH private key for Juju"
}

variable "public_key_path" {
  description = "Path to the SSH private key for Juju"
}

variable "microk8s_charm_channel" {
  type = string
  default = "latest/stable"
}

variable "microk8s_config_channel" {
  type = string
  default = "auto"
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
  default = ["192.168.235.201", "192.168.235.202", "192.168.235.203"]
}

variable "microk8s_kubeconfig" {
  default = "~/.kube/tf_terraform_config"
}