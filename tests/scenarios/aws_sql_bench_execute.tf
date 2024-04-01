variable "controller_info" {
     type = object({
        api_endpoints  = string
        username = string
        password = string
        ca_cert = string
    })
}

provider "juju" {
  alias = "aws-juju"

  controller_addresses = var.controller_info.api_endpoints
  username = var.controller_info.username
  password = var.controller_info.password
  ca_certificate = var.controller_info.ca_cert
}

module "sshuttle_execute" {
    source = "../../utils/sshuttle/"

    jumphost_ip = module.aws_vpc.jumphost_elastic_ip
    subnet = module.aws_vpc.vpc.cidr
    private_key_filepath = module.aws_vpc.private_key_file

}

// --------------------------------------------------------------------------------------
//           Deploy COS Microk8s
// --------------------------------------------------------------------------------------

module "deploy_k8s_vm" {
  source = "../../cloud_providers/aws/k8s/microk8s/"

  providers = {
      aws = aws.us-east1
  }

  vpc_id = module.aws_vpc.vpc_id
  private_subnet_id = module.aws_vpc.private_subnet_id
  aws_key_name = module.aws_vpc.key_name
  aws_private_key_path = module.aws_vpc.private_key_file
  public_key_path = pathexpand("~/.ssh/id_rsa.pub")
  private_key_path = pathexpand("~/.ssh/id_rsa")
  vpc_cidr = module.aws_vpc.vpc.cidr
  ami_id = module.aws_vpc.ami_id
  microk8s_ips = var.microk8s_ips

  depends_on = [module.sshuttle_execute]
}

module "add_microk8s_model" {
    source = "../../cloud_providers/aws/vpc/single_az/add_model/"

    providers = {
        juju = juju.aws-juju
    }

    name = var.microk8s_model_name
    region = module.aws_vpc.vpc.region
    vpc_id = module.aws_vpc.vpc_id
    controller_info = module.aws_juju_bootstrap.controller_info

    depends_on = [module.deploy_k8s_vm]
}

## Seems it is still affected by: https://bugs.launchpad.net/juju/+bug/2039179
module "microk8s_app" {
  source = "../../cloud_providers/k8s/setup/microk8s/"

  providers = {
      juju = juju.aws-juju
  }

  model_name = var.microk8s_model_name
  public_key_path = pathexpand("~/.ssh/id_rsa.pub")
  private_key_path = pathexpand("~/.ssh/id_rsa")
  vpc_cidr = module.aws_vpc.vpc.cidr
  microk8s_ips = var.microk8s_ips
  microk8s_charm_channel = "1.28/stable"

  juju_build_from_git_branch = var.juju_git_branch
  juju_build_with_debug_symbols_code = module.aws_juju_bootstrap.juju_build_with_debug_symbols


  depends_on = [module.add_microk8s_model]
}

// Add the microk8s cloud
module "microk8s_cloud" {
  source = "../../cloud_providers/k8s/add_k8s/"

  controller_name = module.aws_juju_bootstrap.controller_info.name
  microk8s_cloud_name = var.microk8s_cloud_name
  microk8s_host_details = {
    ip = module.deploy_k8s_vm.microk8s_private_ip
    private_key_path = module.deploy_k8s_vm.id_rsa_pub_key
  }


  depends_on = [module.microk8s_app]
}

// --------------------------------------------------------------------------------------
//           Deploy COS metallb
// --------------------------------------------------------------------------------------

resource "juju_model" "metallb_model" {

  name = var.metallb_model_name
  cloud {
    name = var.microk8s_cloud_name
  }

  credential = var.microk8s_cloud_name

  config = {
    logging-config              = "<root>=INFO"
    development                 = true
    update-status-hook-interval = "5m"
  }
  depends_on = [module.microk8s_cloud]
}

module "metallb" {
  source = "../../stacks/metallb/"

  providers = {
      juju = juju.aws-juju
  }

  model_name = var.metallb_model_name
  ip_list = var.microk8s_ips

  depends_on = [juju_model.metallb_model]
}

// --------------------------------------------------------------------------------------
//           Deploy COS
// --------------------------------------------------------------------------------------

resource "juju_model" "cos_model" {

  name = var.cos_model_name
  cloud {
    name = var.microk8s_cloud_name
  }

  credential = var.microk8s_cloud_name

  config = {
    logging-config              = "<root>=INFO"
    development                 = true
    no-proxy                    = "jujucharms.com"
    update-status-hook-interval = "5m"
  }
  depends_on = [module.metallb]
}

module "cos" {
  source = "../../stacks/cos/"

  providers = {
      juju = juju.aws-juju
  }
  cos_model_name = var.cos_model_name

  depends_on = [juju_model.cos_model]
}

// --------------------------------------------------------------------------------------
//           Deploy control models in Juju
// --------------------------------------------------------------------------------------

module "mysql_microk8s_model" {
    source = "../../cloud_providers/aws/vpc/single_az/add_model/"

    count = var.cluster_number

    providers = {
        juju = juju.aws-juju
    }

    name = "mysql-microk8s-${count.index}"
    region = module.aws_vpc.vpc.region
    vpc_id = module.aws_vpc.vpc_id
    controller_info = module.aws_juju_bootstrap.controller_info

    depends_on = [module.cos]
}


resource "juju_machine" "mysql-microk8s-vm" {
    count = var.cluster_number

    model = "mysql-microk8s-${count.index}"

    base = "ubuntu@22.04"
    constraints = "instance-type=c6a.4xlarge root-disk=100G spaces=internal-space"
    depends_on = [module.mysql_microk8s_model]
}

resource "juju_application" "sysbench" {
  count = var.cluster_number

  model = "mysql-microk8s-${count.index}"

  name = "sysbench"
  charm {
    name = "sysbench"
    channel = "latest/edge"
    base = "ubuntu@22.04"
  }
  config = {
    "threads" = 20
  } 
  units = 1
  placement = juju_machine.mysql-microk8s-vm[count.index].machine_id
  depends_on = [module.mysql_microk8s_model, juju_machine.mysql-microk8s-vm]
}

resource "null_resource" "juju_refresh_sysbench" {
  count = var.cluster_number

  provisioner "local-exec" {
    command = <<-EOT
    juju-wait --model=mysql-microk8s-${count.index};
    juju refresh --model mysql-microk8s-${count.index} ${juju_application.sysbench[count.index].name} --path /home/pguimaraes/Documents/Canonical/Engineering/DATAPLATFORM/DPE-3785-epic-sysbench-renewal/2024.03.14/NEW/sysbench-operator/sysbench_ubuntu-22.04-amd64.charm
    EOT
  }
  depends_on = [
    juju_application.sysbench
  ]
}

resource "juju_application" "grafana_agent" {
  count = var.cluster_number

  model = "mysql-microk8s-${count.index}"

  name = "grafana-agent"
  charm {
    name = "grafana-agent"
    channel = "latest/edge"
    base = "ubuntu@22.04"
  }
  depends_on = [null_resource.juju_refresh_sysbench, juju_application.sysbench]
}

resource "juju_integration" "sysbench-grafana_agent-relation" {
  count = var.cluster_number

  model = "control-mysql-${count.index}"

  application {
    name     = juju_application.mysql-microk8s[count.index].name
    endpoint = "database"
  }

  application {
    name     = juju_application.control-mysql-router-k8s[count.index].name
    endpoint = "backend-database"
  }
  depends_on = [null_resource.juju_refresh_sysbench, juju_application.sysbench, juju_application.grafana_agent]
}

resource "juju_integration" grafana_agent-prometheus-relation {
  count = var.cluster_number

  model = "control-mysql-${count.index}"

  application {
    name     = juju_application.grafana_agent[count.index].name
  }
  application {
    offer_url = module.cos.prometheus-rw-offering
  }
  depends_on = [null_resource.juju_refresh_sysbench, juju_application.grafana_agent, juju_integration.sysbench-grafana_agent-relation, module.cos ]
}


resource "juju_application" "mysql-microk8s" {
  count = var.cluster_number

  model = "mysql-microk8s-${count.index}"

  name = "microk8s"
  charm {
    name = "microk8s"
    channel = "1.28/stable"
    base = "ubuntu@22.04"
  }
  units = 1
  placement = juju_machine.mysql-microk8s-vm[count.index].machine_id
  depends_on = [
    juju_machine.mysql-microk8s-vm,
    null_resource.juju_refresh_sysbench
  ]
}

resource "null_resource" "juju_wait_mysql_microk8s" {
  count = var.cluster_number

  provisioner "local-exec" {
    command = <<-EOT
    juju-wait --model=mysql-microk8s-${count.index};
    juju status --format=json --model mysql-microk8s-${count.index} 2>/dev/null | jq -r '.machines."${juju_machine.mysql-microk8s-vm[count.index].machine_id}"."dns-name"' > ./microk8s_ip_${count.index}
    EOT
  }
  depends_on = [juju_application.mysql-microk8s]
}


resource "null_resource" "microk8s-ssh-key" {
  count = var.cluster_number

  provisioner "local-exec" {
    command = <<-EOT
    juju expose --model mysql-microk8s-${count.index} microk8s;
    juju add-ssh-key --model mysql-microk8s-${count.index} "$(cat ${module.aws_vpc.public_key_file})"
    EOT
  }
  depends_on = [null_resource.juju_wait_mysql_microk8s]
}


resource "null_resource" "mysql-microk8s-setup-aws-integration" {
  count = var.cluster_number

  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = chomp(file(module.aws_vpc.private_key_file))
    host = chomp(file("./microk8s_ip_${count.index}"))
  }

  provisioner "file" {
    content = <<-EOT
    #!/bin/bash

    sudo microk8s enable dns helm3

    sudo microk8s helm3 repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
    sudo microk8s helm3 repo update

    sudo microk8s create secret generic aws-secret --namespace kube-system --from-literal "key_id=${var.ACCESS_KEY_ID}" --from-literal "access_key=${var.SECRET_KEY}" || true
    sudo microk8s helm3 upgrade --install aws-ebs-csi-driver --set node.kubeletPath=/var/snap/microk8s/common/var/lib/kubelet --namespace kube-system aws-ebs-csi-driver/aws-ebs-csi-driver

    cat <<EOF | sudo microk8s kubectl apply -f -
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: ebs-sc
    provisioner: ebs.csi.aws.com
    volumeBindingMode: WaitForFirstConsumer
    EOF

    # Now, configure the provider-id for IMDSv2
    # Refs:
    # https://docs.aws.amazon.com/snowball/latest/developer-guide/imds-code-examples.html
    # https://github.com/kubernetes-sigs/aws-ebs-csi-driver/issues/1144
    # https://github.com/canonical/microk8s-aws-addons/blob/29da44495f80903a04852ce8084d12558bb1e2ca/addons/aws-elb-controller/enable#L34
    export TOKEN=`curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone

    export INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    export A_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
    sudo sed -i -n -e '/^--provider-id /!p' -e "\$a--provider-id aws:///$A_ZONE/$INSTANCE_ID" /var/snap/microk8s/current/args/kubelet
    sudo microk8s kubectl patch node $(hostname) -p "{\"spec\":{\"providerID\":\"aws:///$A_ZONE/$INSTANCE_ID\"}}"

    sudo snap restart microk8s.daemon-kubelite
    EOT
    destination = "/tmp/script_microk8s_mysql_setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/script_microk8s_mysql_setup.sh",
      "sudo /tmp/script_microk8s_mysql_setup.sh",
    ]
  }
  depends_on = [null_resource.microk8s-ssh-key]
}

resource "null_resource" "mysql_k8s_save_kubeconfig" {
  count = var.cluster_number


  # Finally, load the new microk8s as another cloud in juju
  provisioner "local-exec" {
    command = "ssh -i ${module.aws_vpc.private_key_file} -o StrictHostKeyChecking=no ubuntu@\"$(cat ./microk8s_ip_${count.index})\" 'sudo microk8s config' | juju add-k8s control-mysql-k8s-${count.index} --storage ebs-sc --client --controller ${module.aws_juju_bootstrap.controller_info.name}"
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [null_resource.mysql-microk8s-setup-aws-integration]
}

resource "juju_model" "mysql_k8s_model" {
  count = var.cluster_number

  name = "control-mysql-k8s-${count.index}"
  cloud {
    name = "control-mysql-k8s-${count.index}"
  }
  credential = "control-mysql-k8s-${count.index}"

  depends_on = [null_resource.mysql_k8s_save_kubeconfig]
}

resource "juju_application" "mysql-k8s" {
  count = var.cluster_number

  model = "control-mysql-k8s-${count.index}"

  name = "mysql"
  charm {
    name = "mysql-k8s"
    channel = "8.0/edge"
    base = "ubuntu@22.04"
  }
  units = 1
  placement = juju_machine.mysql-microk8s-vm[count.index].machine_id
  config = {
    "profile" = "testing"
  }
  depends_on = [juju_model.mysql_k8s_model]
}

resource "juju_application" "control-mysql-router-k8s" {
  count = var.cluster_number

  model = "control-mysql-k8s-${count.index}"

  name = "mysql-router"
  charm {
    name = "mysql-router-k8s"
    channel = "dpe/edge"
    base = "ubuntu@22.04"
  }
  depends_on = [juju_model.mysql_k8s_model]
}


resource "juju_integration" "router-db-relation" {
  count = var.cluster_number

  model = "control-mysql-k8s-${count.index}"

  application {
    name     = juju_application.mysql-microk8s[count.index].name
    endpoint = "database"
  }

  application {
    name     = juju_application.control-mysql-router-k8s[count.index].name
    endpoint = "backend-database"
  }
  depends_on = [juju_application.mysql-k8s, juju_application.control-mysql-router-k8s]
}


resource "null_resource" "juju_refresh_mysql_router_k8s" {
  count = var.cluster_number

  provisioner "local-exec" {
    command = <<-EOT
    juju refresh --model control-mysql-k8s-${count.index} ${juju_application.control-mysql-router-k8s[count.index].name} --path /home/pguimaraes/Documents/Canonical/Engineering/DATAPLATFORM/DPE-3785-epic-sysbench-renewal/mysql-router-k8s-operator/mysql-router-k8s_ubuntu-22.04-amd64.charm
    EOT
  }
  depends_on = [
    juju_application.mysql-k8s,
    juju_application.control-mysql-router-k8s,
    juju_integration.router-db-relation
  ]
}

resource "juju_offer" "mysql_database_k8s" {
  count = var.cluster_number

  model            = "control-mysql-k8s-${count.index}"
  application_name = juju_application.control-mysql-router-k8s[count.index].name
  endpoint         = "database"

  depends_on = [ null_resource.juju_refresh_mysql_router_k8s ]
}



resource "juju_integration" "sysbench-router-relation" {
  count = var.cluster_number

  model = "mysql-microk8s-${count.index}"

  application {
    name     = juju_application.sysbench[count.index].name
    endpoint = "mysql"
  }

  application {
    offer_url = juju_offer.mysql_database_k8s[count.index].url
  }
  depends_on = [
    juju_application.sysbench,
    juju_offer.mysql_database_k8s
  ]
}

resource "null_resource" "juju_execute_sysbench" {
  count = var.cluster_number

  provisioner "local-exec" {
    command = <<-EOT
    juju-wait --model control-mysql-k8s-${count.index};
    juju run --wait=2h --model mysql-microk8s-${count.index} sysbench/0 prepare; 
    juju run --model mysql-microk8s-${count.index} sysbench/0 run
    EOT
  }
  depends_on = [juju_integration.sysbench-router-relation]
}

resource "null_resource" "aws_sql_bench_execute" {
  depends_on = [
    null_resource.juju_execute_sysbench
  ]
}