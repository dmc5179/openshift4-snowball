#!/bin/bash

# Script to deploy httpd, bind, and haproxy
# Run this script after running the configure.sh script

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

read -p "Deploy local DNS? (y/n): " dns

MY_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# Deploy httpd server
echo "Deploying httpd server"
pushd "${SCRIPT_DIR}/playbooks"
ansible-playbook -e ansible_python_interpreter=/usr/bin/python3.9 httpd_server.yaml
popd

# Deploy DNS
if [[ $dns == "y" || $dns == "Y" || $dns == "yes" ]]
then
  echo "Deploying DNS server"
  pushd "${SCRIPT_DIR}/playbooks"
  subnet=$(echo "${MY_IP} | awk -F\. '{print $1"."$2"."$3}')
  ansible-playbook \
    --extra-vars "ansible_python_interpreter=/usr/bin/python3.9 dns_zone_one=${BASE_DOMAIN} bastion_ip=${MY_IP} dns_network=${subnet} bind_forwarder1=34.223.14.129 bind_forwarder2=8.8.8.8" \
    dns_server.yaml
  popd
else
  echo "Skipping local DNS deployment"
fi

# Deploy Load Balancer
echo "Deploying Load Balancer"
pushd "${SCRIPT_DIR}/playbooks"
ansible-playbook \
  --extra-vars "ansible_python_interpreter=/usr/bin/python3.9 bootstrap_ip=${BOOTSTRAP_IP} master0_ip=${MASTER0_IP} master1_ip=${MASTER1_IP} master2_ip=${MASTER2_IP}" \
  load_balancer.yaml
popd
