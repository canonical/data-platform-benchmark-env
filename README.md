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
sudo snap install juju --channel=3.6/stable --classic
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
+--- actions/              Summaries of actions we can use for the different components (opensearch, kafka)
|
|
+--- cloud_providers/      Configures the different VM clouds in Juju
|     |
|     +--- aws/
|         +--- k8s/        This is a special cloud type: we can deploy (setup) or use add-k8s to add an existing k8s cluster
|         +--- setup/      Folder containing the logic to create a new charmed-/microk8s: needs an existing env (another cloud) for that
|
+--- utils/                Additional scripts, such as sshuttle setup.
```

Start with the chosen `cloud_providers` when writing your terraform module. Optionally, use the `examples` folder to kickstart your code.

# Adding a new cloud providers, actions, etc

## Where my new Terraform module goes?

Here is the step-by-step to add your new module to the right place:
```
1) Is it juju-related? If not, then add to utils (e.g. how to setup a proxy or sshuttle)
2) Is it to create a new cloud env? Use cloud_providers/
  2.1) Is it to create a new cloud basic env (e.g. a new VPC), bootstrap a controller or add a new model? -> use the setup/, bootstrap/ and add_model/ respectively
  2.2) Is it how to create a new k8s cluster on top of a given cloud (e.g. GKE, EKS)? Then use k8s/
3) Is it to deploy an app, independent of any cloud? Then, use "stacks/"
4) Is it to deploy an app, dependent of a given cloud? Then, use "cloud_providers/<cloud>/apps" (e.g. aws-integrator in charmed-k8s)
5) Nothing of the above, you've just built a new terraform to bootstrap juju and do a bunch of things on top of all this --> examples/
```

## Non-juju cloud providers

It is possible, with terraform, to automate non-juju cloud providers. That means, we need to have the target cloud's terraform provider to spin up all needed resources + VMs and then use manual provider in juju to add them up.

