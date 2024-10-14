# Benchmark Deployments

This repo is a collection of terraform scripts to get an environment up from 0 on a target cloud, bootstrap juju and start working.

Ideally, you should start only with credentials for your Juju cloud and start deploying.

*IMPORTANT* Intended for people deploying testing environments, these modules will change the entire environment you have and potentially destroy everything at the end!!

The user starts by writing its own terraform module OR using one of the examples available.

# Before You Start

Make sure the following packages and snaps are installed.

```
sudo apt install -y sshuttle python3 python3-jinja2
```

```
sudo snap install terraform --channel=latest/stable --classic
sudo snap install juju --channel=3.1/stable --classic
sudo snap install juju-wait
```

Optionally, also install kubectl to connect with microk8s to check the status of COS:
```
sudo snap install kubectl --channel=<TARGET-VERSION-FOR-K8S>/stable --classic
```

## Folder Structure

The deployment is divided between `cloud_providers`, which contain the setup of a given cloud in certain conditions (e.g. AWS in a single AZ) and `bundle_templates`, which is composed of the different applications to be deployed following some reference decisions, such as running MySQL in HA.

```
+
|
+--- cloud_providers/      Configures the different VM clouds in Juju
|     |
|     +--- k8s/            This is a special cloud type: we can deploy (setup) or use add-k8s to add an existing k8s cluster
|     +--- setup/          Folder containing the logic to create a new charmed-/microk8s: needs an existing env (another cloud) for that
|
+--- stacks/               Configures the different deployment scenarios and testing. Should be used once a model has been correctly added and configured
|
+--- examples/             Examples of complete terraform scripts that use modules from environment and scenarios for a deployment
|
+--- utils/                Additional scripts, such as sshuttle setup.
```

Start with the chosen `cloud_providers` when writing your terraform module. Optionally, use the `examples` folder to kickstart your code.

# Deploying

Choose the `cloud_providers` and `stacks` of interest and start the deployment with a new terraform module.

First, make sure you bootstrap your deployment environment. Each environment folder has a `setup/`, which contains the module to bootstrap that given setup.

Once the basic environment is created and, optionally, a jumphost to the internal network is set: bootstrap juju controller. Both setup and juju bootstrap can happen at the same time.

Then, run the reminder of the deployment.

If you have one single terraform script, it is advised to run something such as:
```
terraform apply -target module.<juju_bootstrap_instance>
terraform apply
```

That will spin the entire environment.

## Interacting with the environment

The examples provided contains a sshuttle routine: it will setup a sshuttle daemon that will give access to the internal private network (e.g. private subnet in AWS VPC).

Use the sshuttle script in `utils/` if you want to jump over a jumphost to your environment.

# Adding a new scenario

## New Scenario

If you plan to bring your own bundle once the deployment is done, then consider the following spaces:
* internal-space: subnets isolated within the tenant and accessible only via a jumphost.
* public-space:  subnets in the public networks, where a Floating/Elastic/Public IP can be assigned to the VM and it becomes externally reachable. In `examples`, this is used to setup the jumphost to access the private subnets

Also, leave standard meta-arguments in the bundle as it will be used as a template for the deployments.

## Where my new Terraform module goes?

Here is the step-by-step to add your new module to the right place:
```
1) Is it juju-related? If not, then add to utils (e.g. how to setup a proxy or sshuttle)
2) Is it to create a new cloud env? Use cloud_providers/
  2.1) Is it to create a new cloud basic env (e.g. a new VPC), bootstrap a controller or add a new model? -> use the setup/, bootstrap/ and add_model/ respectively
  2.2) Is it how to create a new k8s cluster on top of a given cloud (e.g. GKE, EKS)? Then use k8s/
3) Is it to deploy an app, independent of any cloud? Then, use "stacks/"
4) Is it to deploy an app, dependent of a given cloud? Then, use "cloud_providers/<cloud>/apps" (e.g. aws-integrator in charmed-k8s)
5) Nothing of the above, you've just built a new terraform to bootstrap and do a bunch of things on top of all this --> examples/
```

# TODOs

* COS Microk8s VM demands a list of IPs that is consecutive. That is used for metallb
  We need a way to validate that list of IPs
  Ideally, we should not need to specify that list of IPs and get it done by the provider itself
* We need a way to manage the `tfstate` folder: it is important to remember that the state will contain sensitive information such as cloud access keys
