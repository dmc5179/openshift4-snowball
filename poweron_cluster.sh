#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

echo "Collecting OpenShift cluster instance IDs..."

MASTER0_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Master0").InstanceId')

MASTER1_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Master1").InstanceId')

MASTER2_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Master2").InstanceId')

echo "Starting Control Plane Instances"

$EC2 start-instances --instance-ids ${MASTER0_ID} ${MASTER1_ID} ${MASTER2_ID}

exit 0
