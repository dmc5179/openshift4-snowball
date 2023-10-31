#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Script to take in
# - SBE API Endpoint
# - Location of Manifest File
# - SBE Unlock Code

read -p "Enter SnowBall Edge API Endpoint IP Address:  " endpoint
read -p "Enter path to manifest file: " manifest
read -p "Enter Unlock Code: " unlock
read -p "Enter path to SnowBall CA Bundle file: " ca_bundle
read -p "Enter S3 bucket to use on SnowBall: " s3_bucket
read -p "Enter OpenShift base domain name (i.e. mycluster.io): " base_domain
read -p "Enter OpenShift cluster name (i.e ocp4): " cluster_name
read -p "Enter path to SSH public key file: " ssh_key


echo $endpoint
echo $manifest
echo $unlock
echo $ca_bundle
echo $s3_bucket

if ! ping -c 1 "${endpoint}" 2>&1 > /dev/null
then
  echo "Endpoint IP Address unreachable, please retry"
  exit 1
fi

if ! test -f "${manifest}"
then
  echo "${manifest} file not found, please retry"
  exit 1
fi

if ! test -f "${ca_bundle}"
then
  echo "${ca_bundle} file not found, please retry"
  exit 1
fi

exit 0

# - Configure the env.sh file with values passed in to this script
sed -i "s|export ENDPOINT=.*|export ENDPOINT=\"$endpoint\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export MANIFEST=.*|export MANIFEST=\"$manifest\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export UNLOCK=.*|export UNLOCK=\"$unlock\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export CA_BUNDLE=.*|export CA_BUNDLE=\"$ca_bundle\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export S3_BUCKET=.*||" "${SCRIPT_DIR}/env.sh"

# These we have to discover dynamically so source the env file and query
source "${SCRIPT_DIR}/env.sh"

ec2_port=$(snowballEdge describe-service ${OPTS} --service-id ec2 | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')
s3_port=$(snowballEdge describe-service ${OPTS} --service-id s3 | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')

sed -i "s|export EC2_PORT=.*|export EC2_PORT=\"$ec2_port\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export S3_PORT=.*|export S3_PORT=\"$s3_port\"|" "${SCRIPT_DIR}/env.sh"

# TODO: Update Ansible var files

# - Configure ansible playbook default values with values passed in to this script
#cp /home/ec2-user/openshift4-snowball/playbooks/group_vars/all/aws.yml.example \
#    /home/ec2-user/openshift4-snowball/playbooks/group_vars/all/aws.yml

#cp /home/ec2-user/openshift4-snowball/playbooks/group_vars/all/all.yml.example \
#    /home/ec2-user/openshift4-snowball/playbooks/group_vars/all/all.yml

exit 0
