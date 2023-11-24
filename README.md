# Benchmark Deployments

This repo is a collection of terraform scripts to get an environment up from 0 on a target cloud, bootstrap juju and start working.

Ideally, you should start only with credentials for your Juju cloud and start deploying.

*IMPORTANT* The target audience are people deploying testing environments, these modules will destroy everything at the end.

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

The deployment is divided between `environments`, which contain the setup of a given cloud in certain conditions (e.g. AWS in a single AZ) and `scenarios`, which is composed of the different applications to be deployed following some reference decisions, such as running MySQL in HA.

```
+
|
+--- environments/         Configures the different VM clouds in Juju
|     |
|     +--- cos/            Configures the COS environment for any of the following deployments, including the microk8s underneath it
|
+--- scenarios/            Configures the different deployment scenarios and testing. Should be used once a model has been correctly added and configured
```

Start with the chosen `environments` when writing your terraform module. Optionally, use the `examples` folder to kickstart your code.

# Deploying

Choose the `environment` and `scenario` of interest and start the deployment with a new terraform module.

# Adding a new scenario

## New Scenario

If you plan to bring your own bundle once the deployment is done, then consider the following spaces:
* internal-space: subnets isolated within the tenant and accessible only via a jumphost.
* ingress-space:  subnets in the public networks, where a Floating/Elastic/Public IP can be assigned to the VM and it becomes externally reachable.

Also, leave standard meta-arguments in the bundle as it will be used as a template for the deployments.

# TODOs

* Move the examples underneath `environments` to the main folder of the repo
* We need a way to manage the `tfstate` folder: it is important to remember that the state will contain sensitive information such as cloud access keys
* Ideally, use TF_ARG instead of passing secrets via CLI
