#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

export MCS="api-int.${CLUSTER_NAME}.${BASE_DOMAIN}:22623"

echo "q" | openssl s_client -connect $MCS  -showcerts | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' \
  | base64 --wrap=0 | tee /tmp/api-int.base64

sed --regexp-extended --in-place=.backup "s%base64,[a-zA-Z0-9+\/=]+%base64,$(cat /tmp/api-int.base64)%" /tmp/worker.ign

# TODO: Determine the node number to add to instance tags
# Deploy additional worker node
WORKER_INST_ID=$(${EC2} run-instances --image-id ${RHCOS_BASE_AMI_ID} \
  --user-data "file:///tmp/worker.ign" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Worker}]' \
  --instance-type ${MASTER_INSTANCE_TYPE} | jq -r '.Instances[0].InstanceId')

echo "Worker Instance ID: ${WORKER_INST_ID}"

# Get private IPs of cluster nodes
WORKER_PRIVATE_IP=$($EC2 describe-instances --instance-id ${WORKER_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
  
echo "Worker private ip: ${WORKER_PRIVATE_IP}"

# TODO: Add worker node to HAProxy LB for 80/443
# This will require changing the HA proxy ansibe role back
# to using a list of nodes and not hard coded 3 nodes
