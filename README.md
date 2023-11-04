Organization:

+
|
+--- environment/          Configures the different VM clouds in Juju
|     |
|     +--- cos-microk8s/   Configures the COS environment for any of the following deployments, including the microk8s underneath it
|
+--- scenarios/            Configures the different deployment scenarios and testing. Should be used once a model has been correctly added and configured


1) Install terraform and Juju

```
sudo snap install terraform --channel=latest/stable --classic
sudo snap install juju --channel=3.1/stable --classic
```

2) Setup the underneath cloud permissions

3) Run setup TF in the target scenario

4) Juju bootstrap

5) Run scenario TF

6) Collect results
