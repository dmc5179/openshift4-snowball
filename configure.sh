#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Script to take in configuration variables used by ansible and other scripts

read -p "Enter S3 bucket to use on SnowBall: " s3_bucket
read -p "Enter OpenShift base domain name (i.e. mycluster.io): " base_domain
read -p "Enter OpenShift cluster name (i.e ocp4): " cluster_name
read -p "Enter path to SSH public key file: " ssh_key

read -p "Enter bootstrap IP Address: " bootstrap_ip
read -p "Enter Master 0 IP Address: " master0_ip
read -p "Enter Master 1 IP Address: " master1_ip
read -p "Enter Master 2 IP Address: " master2_ip

# - Configure the env.sh file with values passed in to this script
sed -i "s|export S3_BUCKET=.*||" "${SCRIPT_DIR}/env.sh"

sed -i "s|export BOOTSTRAP_IP=.*|export BOOTSTRAP_IP=\"$bootstrap_ip\"|" "${SCRIPT_DIR}/env.sh"
sed -i "s|export MASTER0_IP=.*|export MASTER0_IP=\"$master0_ip\"|" "${SCRIPT_DIR}/env.sh"
sed -i "s|export MASTER1_IP=.*|export MASTER1_IP=\"$master1_ip\"|" "${SCRIPT_DIR}/env.sh"
sed -i "s|export MASTER2_IP=.*|export MASTER2_IP=\"$master2_ip\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export BASE_DOMAIN=.*|export BASE_DOMAIN=\"${base_domain}\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export CLUSTER_NAME=.*|export CLUSTER_NAME=\"${cluster_name}\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export SSH_KEY=.*|export SSH_KEY=\"${ssh_key}\"|" "${SCRIPT_DIR}/env.sh"

# These we have to discover dynamically so source the env file and query
source "${SCRIPT_DIR}/env.sh"

ec2_port=$(snowballEdge describe-service ${SBE_OPTS} --service-id ec2 | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')
s3_port=$(snowballEdge describe-service ${SBE_OPTS} --service-id s3 | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')

sed -i "s|export EC2_PORT=.*|export EC2_PORT=\"$ec2_port\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export S3_PORT=.*|export S3_PORT=\"$s3_port\"|" "${SCRIPT_DIR}/env.sh"

# TODO: Update Ansible var files

# - Configure ansible playbook default values with values passed in to this script
#cp /home/ec2-user/openshift4-snowball/playbooks/group_vars/all/aws.yml.example \
#    /home/ec2-user/openshift4-snowball/playbooks/group_vars/all/aws.yml

#cp /home/ec2-user/openshift4-snowball/playbooks/group_vars/all/all.yml.example \
#    /home/ec2-user/openshift4-snowball/playbooks/group_vars/all/all.yml

exit 0
