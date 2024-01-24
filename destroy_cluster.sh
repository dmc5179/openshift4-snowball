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

# TODO: This doesn't handle when old OCP nodes are in the terminated state but still show in the describe-instances call
BOOTSTRAP_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Bootstrap").InstanceId')

MASTER0_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Master0").InstanceId')

MASTER1_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Master1").InstanceId')

MASTER2_ID=$($EC2 describe-instances | jq -r -c '.Reservations[].Instances[] | select(.Tags[0].Value=="Master2").InstanceId')

if [[ ! -z "${BOOTSTRAP_ID}" ]]
then

  echo "Destroying Bootstrap Instance"
  for i in ${BOOTSTRAP_ID}
  do
    $EC2 terminate-instances --instance-ids "${i}"
  done
fi

if [[ ! -z "${MASTER0_ID}" ]]
then

  echo "Destroying Master 0 Instance"
  for i in ${MASTER0_ID}
  do
    $EC2 terminate-instances --instance-ids "${i}"
  done

fi

if [[ ! -z "${MASTER1_ID}" ]]
then

  echo "Destroying Master 1 Instance"
  for i in ${MASTER1_ID}
  do
    $EC2 terminate-instances --instance-ids "${i}"
  done

fi

if [[ ! -z "${MASTER2_ID}" ]]
then

  echo "Destroying Master 2 Instance"
  for i in ${MASTER2_ID}
  do
    $EC2 terminate-instances --instance-ids "${i}"
  done

fi

exit 0
