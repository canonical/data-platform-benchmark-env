// --------------------------------------------------------------------------------------
//      Contains all the common variables. Modules may define their own vars as well
// --------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------
//      Varibles that must be set
// --------------------------------------------------------------------------------------

variable "ACCESS_KEY_ID" {
    type      = string
    sensitive = true
}

variable "SECRET_KEY" {
    type      = string
    sensitive = true
}

variable "region" {
    type = string
}

// --------------------------------------------------------------------------------------
//      Varibles that must be set
// --------------------------------------------------------------------------------------

variable "fan_networking_cidr" {
    type = string
    default = "252.0.0.0/8"
}

variable "microk8s_model_name" {
    type = string
    default = "microk8s"
}

variable "opensearch_charm_channel" {
    type = string
    default = "2/edge"
}

variable "microk8s_ips" {
    type = list(string)
    default = ["192.168.235.231", "192.168.235.232", "192.168.235.233"]
}

variable "microk8s_cloud_name" {
    type = string
    default = "test-k8s"
}

variable cos_bundle {
  type = string
  default = "../../cloud_providers/k8s/cos/bundle.yaml"
}

variable cos_overlay_bundle {
  type = string
  default = "../../cloud_providers/k8s/cos/cos-overlay.yaml"
}

variable cos_model_name {
  type = string
  default = "cos"
}

variable charmed_k8s_model_name {
  type = string
  default = "charmed-k8s"
}

variable metallb_model_name {
  type = string
  default = "metallb"
}

variable cluster_number {
  type = number
  default = 1
}

variable "vpc" {
  type = object({
    name   = string
    region = string
    az     = string
    cidr   = string
  })
  default = {
    name   = "test-vpc"
    region = "us-east-1"
    az     = "us-east-1a"
    cidr   = "192.168.234.0/23"
  }
}

variable "spaces" {
  type = list(object({
    name = string
    subnets = list(string)
  }))
    default = [
    {
      name = "internal-space"
      subnets = ["192.168.235.0/24"]
    },
  ]
}

// --------------------------------------------------------------------------------------
//      Juju built from source variables (specifying will trigger a full build)
// --------------------------------------------------------------------------------------

variable "agent_version" {
    type = string
    default = ""
}

variable "juju_build_agent_path" {
    type = string
    default = ""
}

variable "juju_git_branch" {
    type = string
    default = ""
}
