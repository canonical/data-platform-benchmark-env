This is composed of all the different modules, sewed together for testing.

Essentially, every test is a scenario, divided by naming:
*_bootstrap: creates the basis of the cloud (e.g. VPC or tenant OpenStack) + Juju controller
*_execute: runs the actual test

Each file should finish with a "null_resource" holding the respective *_bootstrap or *_execute name.
Unfortunately, TF does not support calling "all methods of a given TF file". This is a workaround.

Global variables, that may be used by any module, should be declared in "variables.tf". Any local
variable must have the scenario name as its prefix, so we have a namespace for several tests, e.g.:

```
variable aws_sql_bench_...<var> {

}
```