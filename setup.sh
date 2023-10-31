#!/bin/bash

# Script to deploy httpd, bind, and haproxy
# Run this script after running the configure.sh script

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

# Deploy httpd server
echo "Deploying httpd server"
pushd "${SCRIPT_DIR}/playbooks"
ansible-playbook httpd_server.yaml
popd

# Deploy DNS
echo "Deploying DNS server"
pushd "${SCRIPT_DIR}/playbooks"
subnet=$(hostname -i | awk -F\. '{print $1"."$2"."$3}')
ansible-playbook \
  --extra-vars "dns_zone_one=${BASE_DOMAIN} bastion_ip=$(hostname -i) dns_network=${subnet} bind_forwarder1=34.223.14.129 bind_forwarder2=8.8.8.8" \
  dns_server.yaml
popd

# Deploy Load Balancer
echo "Deploying Load Balancer"
pushd "${SCRIPT_DIR}/playbooks"
ansible-playbook \
  --extra-vars "bootstrap_ip=${BOOTSTRAP_IP} master0_ip=${MASTER0_IP} master1_ip=${MASTER1_IP} master2_ip=${MASTER2_IP}" \
  load_balancer.yaml
popd
