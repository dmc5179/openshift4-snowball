#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

read -p "Destroy OpenShift Cluster? (y/n): " destroy

if [[ $destroy != "y" && $destroy != "Y" && $destroy != "yes" ]]
then
  echo "Exiting without destroying the OpenShift cluster"
  exit 0
fi

echo "Collecting OpenShift cluster instance IDs..."

BOOTSTRAP_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Bootstrap").InstanceId')

MASTER0_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Master0").InstanceId')

MASTER1_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Master1").InstanceId')

MASTER2_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Master2").InstanceId')

if [[ ! -z "${BOOTSTRAP_ID}" ]]
then

  echo "Destroying Bootstrap Instance"
  $EC2 terminate-instances --instance-ids "${BOOTSTRAP_ID}"
fi

if [[ ! -z "${MASTER0_ID}" ]]
then

  echo "Destroying Master 0 Instance"
  $EC2 terminate-instances --instance-ids "${MASTER0_ID}"
fi

if [[ ! -z "${MASTER1_ID}" ]]
then

  echo "Destroying Master 1 Instance"
  $EC2 terminate-instances --instance-ids "${MASTER1_ID}"

fi

if [[ ! -z "${MASTER2_ID}" ]]
then

  echo "Destroying Master 2 Instance"
  $EC2 terminate-instances --instance-ids "${MASTER2_ID}"

fi

exit 0
