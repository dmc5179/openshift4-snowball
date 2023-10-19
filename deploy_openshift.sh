#!/bin/bash -e

# Script to deploy a 3 node OpenShift cluster on an AWS Snowball Edge device
# The AWS ansible collections do not support the Snowball Edge devices

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

BOOTSTRAP_ENI=""
MASTER0_ENI=""
MASTER1_ENI=""
MASTER2_ENI=""

# Generate Ignition Configs
#echo "Generating Ignition Configuration"
#pushd "${SCRIPT_DIR}/playbooks"
#ansible-playbook generate_ignition.yaml
#popd

# Stage Ignition Configs in S3
#echo "Staging Ignition Configs in local httpd server"
#./stage_ignition.sh

# Create custom RAW disk files for the bootstrap and control plane nodes
./load_custom_amis.sh
#TODO: Not getting the bootstrap and master AMI IDs back from this script
# TODO: create VNI nic. Assign at launch 
# TODO: Don't create VNIs outside the SBE CIDR or S3 will not start

# Deploy Bootstrap node
# TODO: User data is limited to 16KB which is too small for the bootstrap
#       Need to include ignition config that points bootstrap to S3
#ENCODED_USER_DATA=$(jq -r -c '.' append_ignition.ign | base64 -w 0)
BOOTSTRAP_INST_ID=$(${EC2} run-instances --image-id ${BOOTSTRAP_AMI} \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Bootstrap}]' \
  --instance-type sbe-c.2xlarge | jq -r '.Instances[0].InstanceId')

echo "Bootstrap Instance ID: ${BOOTSTRAP_INST_ID}"

# Need to wait for instance to reach a certain state before we can associate and address
#sleep 20
until [[ `$EC2 describe-instances --instance-ids ${BOOTSTRAP_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name'` == "running" ]]
do
  echo "Waiting for bootstrap to reach running state for VNI attachment...."
  echo -n "Current state: "
  $EC2 describe-instances --instance-ids ${BOOTSTRAP_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name'
  sleep 5
done

$EC2 associate-address --instance-id ${BOOTSTRAP_INST_ID} --public-ip 192.168.1.247


#MASTER0_INST_ID=$(${EC2} run-instances --image-id ${MASTER_AMI} \
#  --instance-type sbe-c.2xlarge | jq -r '.Instances[0].InstanceId')

#MASTER1_INST_ID=$(${EC2} run-instances --image-id ${MASTER_AMI} \
#  --instance-type sbe-c.2xlarge | jq -r '.Instances[0].InstanceId')

#MASTER2_INST_ID=$(${EC2} run-instances --image-id ${MASTER_AMI} \
#  --instance-type sbe-c.2xlarge | jq -r '.Instances[0].InstanceId')

# Need to wait a few seconds before trying to get the private IP assigned to the instance at launch
#sleep 5

#BOOTSTRAP_IP=$(${EC2} describe-instances --instance-ids ${BOOTSTRAP_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
#MASTER0_IP=$(${EC2} describe-instances --instance-ids ${MASTER0_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
#MASTER1_IP=$(${EC2} describe-instances --instance-ids ${MASTER1_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
#MASTER2_IP=$(${EC2} describe-instances --instance-ids ${MASTER2_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

#echo "Bootstrap IP: ${BOOTSTRAP_IP}"

############################################
#TODO:  After OCP nodes are started, update the DNS configuration to use their new IP addresses if needed


#exit 0
