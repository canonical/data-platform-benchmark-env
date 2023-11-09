Start only with credentials for your Juju cloud and start deploying.

A bag of terraform scripts to setup environments on popular clouds.

Depends on:
- sshuttle
- python3
- python3-jinja2
- juju
- terraform

If you plan to bring your own bundle once the deployment is done, then consider the following spaces:
* internal-space: subnets isolated within the tenant and accessible only via a jumphost.
* ingress-space:  subnets in the public networks, where a Floating/Elastic/Public IP can be assigned to the VM and it becomes externally reachable.


Organization:

```
+
|
+--- environment/          Configures the different VM clouds in Juju
|     |
|     +--- cos-microk8s/   Configures the COS environment for any of the following deployments, including the microk8s underneath it
|
+--- scenarios/            Configures the different deployment scenarios and testing. Should be used once a model has been correctly added and configured
```


1) Install terraform and Juju

```
sudo snap install terraform --channel=latest/stable --classic
sudo snap install juju --channel=3.1/stable --classic
```

2) Setup the underneath cloud permissions

2.1) AWS
Setup an user and create an access key, as described [in aws docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)



TODO: check if the step below is really needed
Install the aws-cli snap and create the files as described below.

```
~/.aws/config
[default]
region = us-east-1
output = text

~/.aws/credentials
[default]
aws_access_key_id = ...
aws_secret_access_key = ...
```


3) Run setup TF in the target scenario

4) Juju bootstrap

5) Run scenario TF

6) Collect results
