#!/usr/bin/env python3

import json
import yaml
import os
import jinja2
import uuid
import time


ts = int(time.time())
id = str(uuid.uuid4())


REGION_TXT = "us-east-1"
VPC_CIDR_TXT = "192.168.240.0/22"
TAGS_TXT = """CI: true"""
PUBLIC_CIDR_TXT = "192.168.240.0/24"
PRIVATE_CIDRS_TXT = """private_cidr1:
  cidr: 192.168.241.0/24
  az: us-east-1a
private_cidr2:
  cidr: 192.168.242.0/24
  az: us-east-1b
private_cidr3:
  cidr: 192.168.243.0/24
  az: us-east-1c
"""


private_cidrs = {
  key: {
    "name": key,
    "cidr": value["cidr"],
    "az": value["az"]
  }
  for key, value in yaml.safe_load(PRIVATE_CIDRS_TXT).items()
}

public_cidrs = {
  "name": "public_cidr",
  "cidr": PUBLIC_CIDR_TXT,
  "az": "{}a".format(REGION_TXT)
}

args = {
  "region": REGION_TXT,
  "vpc_cidr": VPC_CIDR_TXT,
  "tags": yaml.safe_load(TAGS_TXT),
  "public_cidr": public_cidrs,
  "private_cidrs": private_cidrs,
  "timestamp": ts,
  "id": id,
  "public_cidrs_to_space": str([public_cidrs['cidr']]).replace("'", '"'),
  "private_cidrs_to_space": str([arg['cidr'] for arg in private_cidrs.values()]).replace("'", '"'),
}

args["tags"]["CI"] = "true"

template_tfvars="""vpc = {
  name   = "test-vpc"
  region = "{{ args['region']  }}"
  cidr   = "{{ args['vpc_cidr'] }}"
}

provider_tags = {
{%- for tag, val in args['tags'].items() %}
  {{ tag }} = "{{ val }}"
{%- endfor %}
}

public_cidr = {
{%- for key, val in args['public_cidr'].items() %}
  {{ key }} = "{{ val }}"
{%- endfor %}
  run_id = "run-{{ args['timestamp'] }}-{{ args['id'] }}"
}

spaces = [
  {
    name    = "public-space"
    subnets = {{ args['public_cidrs_to_space'] }}
  },
  {
    name    = "private-space"
    subnets = {{ args["private_cidrs_to_space"] }}
  },
]

private_cidrs = {
{%- for subnet_name, subnet in args['private_cidrs'].items() %}
  {{ subnet_name }} = {
    cidr = "{{ subnet['cidr'] }}"
    name = "{{ subnet['name'] }}"
    az = "{{ subnet['az'] }}"
  }
{%- endfor %}
}

model_name = "{{ args['model_name'] }}"
"""
environment = jinja2.Environment()
template = environment.from_string(template_tfvars)
output = template.render(args=args)
with open("terraform.tfvars", "w") as file:
    file.write(template.render(args=args))
