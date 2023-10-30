#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

# Deploy httpd server to host ignition configs
# This is due to EC2 user data size limitations
echo "Installing HTTPD"

pushd "${SCRIPT_DIR}/playbooks"

ansible-playbook httpd_server.yaml

popd
