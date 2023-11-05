
resource "juju_credential" "aws_creds" {
  name = var.aws_creds_name

  cloud {
    name = "aws"
  }

  auth_type = "access-key"

  attributes = {
    auth-key   = var.access_key.auth_key
    secret-key = var.access_key.secret_key
  }
}

resource "terraform_data" "bootstrap" {

  provisioner "local-exec" {
    command = "juju bootstrap aws --credential ${var.aws_creds_name}  --model-default vpc-id=${var.vpc_id} --model-default vpc-id-force=true --config vpc-id=${var.vpc_id} --config vpc-id-force=true --constraints 'instance-type=${var.instance_type} root-disk=${var.root_disk_size}' --to subnet=${var.private_cidr}"
  }

  depends-on: ["aws_creds"]
}
