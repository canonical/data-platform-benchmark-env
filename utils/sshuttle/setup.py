#!/usr/bin/python3

import subprocess
import jinja2

environment = jinja2.Environment()
with open("sshuttle_tunnel.service.j2") as f:
    template = environment.from_string(f.read())

with open("/etc/systemd/system/test-tunnel", mode="w") as f:
    f.write(
        template.render(
            jumphost_ip=jumphost_ip,
            cidr=cidr,
            keypath=keypath
        )
    )
    f.close()

subprocess.check_output(["systemctl", "enable", "test-tunnel"])
subprocess.check_output(["systemctl", "start", "test-tunnel"])