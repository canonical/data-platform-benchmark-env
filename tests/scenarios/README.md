This is composed of all the different modules, sewed together for testing.

Essentially, every test is a scenario, divided by naming:
*_bootstrap: creates the basis of the cloud (e.g. VPC or tenant OpenStack) + Juju controller
*_execute: runs the actual test