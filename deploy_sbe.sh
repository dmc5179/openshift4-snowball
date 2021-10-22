#!/bin/bash

sudo dnf -y install podman
sudo systemctl enable podman.socket
sudo systemctl restart podman.socker
sudo systemctl enable podman.service
sudo systemctl restart podman.service

# Pull the registry container image
curl -X POST --unix-socket /run/podman/podman.sock  http://d/v3.0.0/libpod/images/pull?reference=docker.io/library/registry:2

# Pull the haproxy load balancer image

# Pull the bind server image

