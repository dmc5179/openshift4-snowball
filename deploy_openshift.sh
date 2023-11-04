#!/bin/bash -e

# Script to deploy a 3 node OpenShift cluster on an AWS Snowball Edge device
# The AWS ansible collections do not support the Snowball Edge devices

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

BOOTSTRAP_UD="merge_bootstrap.ign"
MASTER_UD="merge_master.ign"

MY_IP=$(hostname -i)

# Generate Ignition Configs
echo "Generating Ignition Configuration"
pushd "${SCRIPT_DIR}/playbooks"
ansible-playbook -e ansible_python_interpreter=/usr/bin/python3.9 generate_ignition.yaml
popd

# Stage Ignition Configs in S3
echo "Staging Ignition Configs in local httpd server"
pushd "${SCRIPT_DIR}/playbooks"
ansible-playbook -e ansible_python_interpreter=/usr/bin/python3.9 stage_ignition.yaml
popd

#exit 0

# Write instance ids to file
rm -f /tmp/ocp_instances.txt
touch /tmp/ocp_instances.txt

# Deploy Bootstrap node
BOOTSTRAP_INST_ID=$(${EC2} run-instances --image-id ${RHCOS_BASE_AMI_ID} \
  --user-data "file://${BOOTSTRAP_UD}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Bootstrap}]' \
  --instance-type sbe-c.xlarge | jq -r '.Instances[0].InstanceId')

echo "Bootstrap Instance ID: ${BOOTSTRAP_INST_ID}"
echo "${BOOTSTRAP_INST_ID}" >> /tmp/ocp_instances.txt

# Need to wait for instance to reach a certain state before we can associate and address
state="x"
until [[ "$state" == "running" ]]
do
  echo "Waiting for bootstrap to reach running state for VNI attachment...."
  state=$($EC2 describe-instances --instance-ids ${BOOTSTRAP_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name')
  echo "Current state: ${state} "
  sleep 5
done

$EC2 associate-address --instance-id ${BOOTSTRAP_INST_ID} --public-ip "${BOOTSTRAP_IP}"

BOOTSTRAP_PRIVATE_IP=$($EC2 describe-instances --instance-id ${BOOTSTRAP_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

echo "Bootstrap private ip: ${BOOTSTRAP_PRIVATE_IP}"

#exit 0

#########################################################################################################
# Master 0

MASTER0_INST_ID=$(${EC2} run-instances --image-id ${RHCOS_BASE_AMI_ID} \
  --user-data "file://${MASTER_UD}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Master0}]' \
  --instance-type sbe-c.xlarge | jq -r '.Instances[0].InstanceId')

echo "Master 0 Instance ID: ${MASTER0_INST_ID}"
echo "${MASTER0_INST_ID}" >> /tmp/ocp_instances.txt

# Need to wait for instance to reach a certain state before we can associate and address
until [[ `$EC2 describe-instances --instance-ids ${MASTER0_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name'` == "running" ]]
do
  echo "Waiting for master 0 to reach running state for VNI attachment...."
  echo -n "Current state: "
  $EC2 describe-instances --instance-ids ${MASTER0_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name'
  sleep 5
done

$EC2 associate-address --instance-id ${MASTER0_INST_ID} --public-ip "${MASTER0_IP}"

MASTER0_PRIVATE_IP=$($EC2 describe-instances --instance-id ${MASTER0_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

echo "Master 0 private ip: ${MASTER0_PRIVATE_IP}"


############################################################################################################
# Master 1
MASTER1_INST_ID=$(${EC2} run-instances --image-id ${RHCOS_BASE_AMI_ID} \
  --user-data "file://${MASTER_UD}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Master1}]' \
  --instance-type sbe-c.xlarge | jq -r '.Instances[0].InstanceId')

echo "Master 1 Instance ID: ${MASTER1_INST_ID}"
echo "${MASTER1_INST_ID}" >> /tmp/ocp_instances.txt

# Need to wait for instance to reach a certain state before we can associate and address
until [[ `$EC2 describe-instances --instance-ids ${MASTER1_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name'` == "running" ]]
do
  echo "Waiting for master 1 to reach running state for VNI attachment...."
  echo -n "Current state: "
  $EC2 describe-instances --instance-ids ${MASTER1_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name'
  sleep 5
done

$EC2 associate-address --instance-id ${MASTER1_INST_ID} --public-ip "${MASTER1_IP}"

MASTER1_PRIVATE_IP=$($EC2 describe-instances --instance-id ${MASTER1_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

echo "Master 1 private ip: ${MASTER1_PRIVATE_IP}"

##########################################################################################################
# Master 2
MASTER2_INST_ID=$(${EC2} run-instances --image-id ${RHCOS_BASE_AMI_ID} \
  --user-data "file://${MASTER_UD}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Master2}]' \
  --instance-type sbe-c.xlarge | jq -r '.Instances[0].InstanceId')

echo "Master 2 Instance ID: ${MASTER2_INST_ID}"
echo "${MASTER2_INST_ID}" >> /tmp/ocp_instances.txt

# Need to wait for instance to reach a certain state before we can associate and address
until [[ `$EC2 describe-instances --instance-ids ${MASTER2_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name'` == "running" ]]
do
  echo "Waiting for master 2 to reach running state for VNI attachment...."
  echo -n "Current state: "
  $EC2 describe-instances --instance-ids ${MASTER2_INST_ID} | jq -r '.Reservations[0].Instances[0].State.Name'
  sleep 5
done

$EC2 associate-address --instance-id ${MASTER2_INST_ID} --public-ip "${MASTER2_IP}"

MASTER2_PRIVATE_IP=$($EC2 describe-instances --instance-id ${MASTER2_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

echo "Master 2 private ip: ${MASTER2_PRIVATE_IP}"

echo "Master 0 private ip: ${MASTER0_PRIVATE_IP}"
echo "Master 1 private ip: ${MASTER1_PRIVATE_IP}"
echo "Master 2 private ip: ${MASTER2_PRIVATE_IP}"


#exit 0
