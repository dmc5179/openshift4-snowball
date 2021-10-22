#!/bin/bash

sudo dnf -y install podman ansible
#sudo systemctl enable podman.socket
#sudo systemctl restart podman.socker
#sudo systemctl enable podman.service
#sudo systemctl restart podman.service

# TODO: Install Ansible role for haproxy
# TODO: Need to update the haproxy role to run in a container and not directly on the host

# TODO: Install Ansible role for podman registry

# TODO: Install Ansible role for bind DNS server
# TODO: Need to update bind DNS server role to run in a container and not directly on the host

# TODO: Install Ansible role for httpd web server
# TODO: Need to update httpd web server role to run in a container and not directly on the host
