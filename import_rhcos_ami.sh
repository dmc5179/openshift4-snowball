#!/bin/bash
#
# This script is intended to be run on the OpenShift Content Instance inside the AWS SBE
# It will load the RHCOS RAW Disk Image file from S3 on the SBE into an AMI on the SBE
# to be used when installing the OpenShift cluster on the SBE.


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

function usage {

  echo "Usage: $0 <s3_bucket> [volume_type]"
}

if [[ $# < 1 ]]
then
  usage
  exit 1
fi

S3_BUCKET="${1}"

# Default to SBE volume type
VOL_TYPE="sbp1"
if [[ $# == 2 ]]
then
  VOL_TYPE="${2}"
fi

##############################################
# RHCOS Snapshot

#Copy the RHCOS RAW disk from the SBE into S3 on the SBE
${S3} cp "${RHCOS_IMG}" "s3://${S3_BUCKET}/"

# Create required config file for EC2 snapshot import process
rm -f /tmp/containers.json
cat << EOF > /tmp/containers.json
{ 
    "Description": "Red Hat CoreOS ${RHCOS_VER}",
    "Format": "RAW",
    "UserBucket": {
        "S3Bucket": "${S3_BUCKET}",
        "S3Key": "$(basename ${RHCOS_IMG})"
    }
}
EOF

RHCOS_IMPORT_ID=$( ${EC2} import-snapshot --disk-container "file:///tmp/containers.json" |  jq -r '.ImportTaskId')

echo "RHCOS Snapshot import ID: ${RHCOS_IMPORT_ID}"

x="unknown"
echo "Snapshot import takes 5-10 minutes in most cases"
date
while [[ "$x" != "completed" ]]
do
  echo "Waiting for snapshot import to complete"
  x=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${RHCOS_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.Status')
  sleep 5
done

RHCOS_SNAPSHOT=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${RHCOS_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId')

echo "RHCOS snapshot ID: ${RHCOS_SNAPSHOT}"

sleep 5

# Register the AMI
RHCOS_AMI=$(${EC2} register-image \
  --output text \
  --name "rhcos-${RHCOS_VER}" \
  --description "rhcos-${RHCOS_VER}" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"SnapshotId\":\"${RHCOS_SNAPSHOT}\",\"VolumeType\":\"${VOL_TYPE}\",\"DeleteOnTermination\":true}}]" \
  --root-device-name /dev/sda1)

echo "RHCOS AMI: ${RHCOS_AMI}"

exit 0
