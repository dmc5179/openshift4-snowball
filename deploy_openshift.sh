#!/bin/bash -e

# Script to deploy a 3 node OpenShift cluster on an AWS Snowball Edge device
# The AWS ansible collections do not support the Snowball Edge devices

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

# These files are installed by the httpd ansible role
# Do not change these unless using a non-default merge file
BOOTSTRAP_UD="/var/www/html/ignition/merge_bootstrap.ign"
MASTER_UD="/var/www/html/ignition/merge_master.ign"

BOOTSTRAP_INSTANCE_TYPE="sbe-c.2xlarge"
MASTER_INSTANCE_TYPE="sbe-c.2xlarge"

MY_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# Variables to pass when calling ansible-playbook
ANSIBLE_VARS="ssh_key_file=${SSH_KEY} ocp_base_domain=${BASE_DOMAIN} ocp_cluster_name=${CLUSTER_NAME} rhcos_ami=${RHCOS_BASE_AMI_ID} disconnected=true"

# Generate Ignition Configs
echo "Generating Ignition Configuration"
pushd "${SCRIPT_DIR}/playbooks"
ansible-playbook -e "${ANSIBLE_VARS}" generate_ignition.yaml
popd

# Stage Ignition Configs in S3
echo "Staging Ignition Configs in local httpd server"
pushd "${SCRIPT_DIR}/playbooks"
ansible-playbook -e "${ANSIBLE_VARS}" stage_ignition.yaml
popd

#exit 0

# Deploy Bootstrap node
BOOTSTRAP_INST_ID=$(${EC2} run-instances --image-id ${RHCOS_BASE_AMI_ID} \
  --user-data "file://${BOOTSTRAP_UD}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Bootstrap}]' \
  --instance-type ${BOOTSTRAP_INSTANCE_TYPE} | jq -r '.Instances[0].InstanceId')

echo "Bootstrap Instance ID: ${BOOTSTRAP_INST_ID}"

# Deploy Control Plane 0 node
MASTER0_INST_ID=$(${EC2} run-instances --image-id ${RHCOS_BASE_AMI_ID} \
  --user-data "file://${MASTER_UD}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Master0}]' \
  --instance-type ${MASTER_INSTANCE_TYPE} | jq -r '.Instances[0].InstanceId')

echo "Master 0 Instance ID: ${MASTER0_INST_ID}"

# Deploy Control Plane 1 node
MASTER1_INST_ID=$(${EC2} run-instances --image-id ${RHCOS_BASE_AMI_ID} \
  --user-data "file://${MASTER_UD}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Master1}]' \
  --instance-type ${MASTER_INSTANCE_TYPE} | jq -r '.Instances[0].InstanceId')

echo "Master 1 Instance ID: ${MASTER1_INST_ID}"

# Deploy Control Plane 2 node
MASTER2_INST_ID=$(${EC2} run-instances --image-id ${RHCOS_BASE_AMI_ID} \
  --user-data "file://${MASTER_UD}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Master2}]' \
  --instance-type ${MASTER_INSTANCE_TYPE} | jq -r '.Instances[0].InstanceId')

echo "Master 2 Instance ID: ${MASTER2_INST_ID}"

# Get private IPs of cluster nodes
BOOTSTRAP_PRIVATE_IP=$($EC2 describe-instances --instance-id ${BOOTSTRAP_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

echo "Bootstrap private ip: ${BOOTSTRAP_PRIVATE_IP}"
 
MASTER0_PRIVATE_IP=$($EC2 describe-instances --instance-id ${MASTER0_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

echo "Master 0 private ip: ${MASTER0_PRIVATE_IP}"

MASTER1_PRIVATE_IP=$($EC2 describe-instances --instance-id ${MASTER1_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

echo "Master 1 private ip: ${MASTER1_PRIVATE_IP}"

MASTER2_PRIVATE_IP=$($EC2 describe-instances --instance-id ${MASTER2_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

echo "Master 2 private ip: ${MASTER2_PRIVATE_IP}"

# Reconfigure HA proxy with new private IP addresses
echo "Deploying Load Balancer"
pushd "${SCRIPT_DIR}/playbooks"
ansible-playbook \
  --extra-vars "ansible_python_interpreter=/usr/bin/python3.9 bootstrap_ip=${BOOTSTRAP_PRIVATE_IP} master0_ip=${MASTER0_PRIVATE_IP} master1_ip=${MASTER1_PRIVATE_IP} master2_ip=${MASTER2_PRIVATE_IP}" --tags reconfigure \
  load_balancer.yaml
popd

# Wait for nodes to reach the running state and attach VNIs

# Bootstrap
state="x"
until [[ "$state" == "running" ]]
do
  echo "Waiting for bootstrap to reach running state for VNI attachment...."
  state=$($EC2 describe-instances --instance-ids ${BOOTSTRAP_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name')
  echo "Current state: ${state} "
  sleep 5
done

$EC2 associate-address --instance-id ${BOOTSTRAP_INST_ID} --public-ip "${BOOTSTRAP_IP}"

# Master 0

state="x"
until [[ "$state" == "running" ]]
do
  echo "Waiting for master 0 to reach running state for VNI attachment...."
  state=$($EC2 describe-instances --instance-ids ${MASTER0_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name')
  echo "Current state: ${state} "
  sleep 5
done

$EC2 associate-address --instance-id ${MASTER0_INST_ID} --public-ip "${MASTER0_IP}"

############################################################################################################
# Master 1

state="x"
until [[ "$state" == "running" ]]
do
  echo "Waiting for Master 1 to reach running state for VNI attachment...."
  state=$($EC2 describe-instances --instance-ids ${MASTER1_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name')
  echo "Current state: ${state} "
  sleep 5
done

$EC2 associate-address --instance-id ${MASTER1_INST_ID} --public-ip "${MASTER1_IP}"

##########################################################################################################
# Master 2

state="x"
until [[ "$state" == "running" ]]
do
  echo "Waiting for Master 2 to reach running state for VNI attachment...."
  state=$($EC2 describe-instances --instance-ids ${MASTER2_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name')
  echo "Current state: ${state} "
  sleep 5
done

$EC2 associate-address --instance-id ${MASTER2_INST_ID} --public-ip "${MASTER2_IP}"

#echo "Master 0 private ip: ${MASTER0_PRIVATE_IP}"
#echo "Master 1 private ip: ${MASTER1_PRIVATE_IP}"
#echo "Master 2 private ip: ${MASTER2_PRIVATE_IP}"

# Wating for cluster to complete
echo "Beyond this point this script can be Ctrl-C'd and the cluster formation will continue"
echo "From here we are only providing status on the cluster install"

openshift-install wait-for bootstrap-complete --log-level=debug --dir=/opt/openshift/cluster/

openshift-install wait-for install-complete --log-level=debug --dir=/opt/openshift/cluster/

if [[ $? == 0 ]]
then
  echo "Cluster Install Complete. Destroying Bootstrap Node"
  $EC2 terminate-instances --instance-ids ${BOOTSTRAP_INST_ID}
fi

#exit 0
