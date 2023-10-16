#!/bin/bash
#
# This script is intended to be run from outside the AWS SBE device.
# It is used to import the OpenShift Content RAW Disk located in S3 on the SBE
# Once the OpenShift Content AMI is loaded and instance running, everything else is run from the content AMI
#
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

function usage {

  echo "Usage: $0 <s3_bucket> <path_to_ami_raw_disk_file_in_s3_bucket> [volume_type]"
}

if [[ $# < 2 ]]
then
  usage
  exit 1
fi

S3_BUCKET="${1}"
S3_PATH="${2}"

# Default to SBE volume type
VOL_TYPE="sbp1"
if [[ $# == 3 ]]
then
  VOL_TYPE="${3}"
fi

##############################################
# Content Snapshot

# Create file required by the AWS import snapshot command
rm -f /tmp/containers.json
 
cat << EOF > /tmp/containers.json
{ 
    "Description": "Red Hat OpenShift 4 ${OCP_VER} Content Image",
    "Format": "RAW",
    "UserBucket": {
        "S3Bucket": "${S3_BUCKET}",
        "S3Key": "${S3_PATH}"
    }
}
EOF

# Import the snapshot and get the import task ID
# TODO: This command did not capture the import snapshot task ID
CONTENT_IMPORT_ID=$( ${EC2} import-snapshot --disk-container "file:///tmp/containers.json" |  jq -r '.ImportTaskId')

echo "Content Snapshot import ID: ${CONTENT_IMPORT_ID}"

# Wait for the snapshot import to complete
x="unknown"
echo "Snapshot import takes 5-10 minutes in most cases"
date
while [[ "$x" != "completed" ]]
do
  echo "Waiting for snapshot import to complete"
  x=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${CONTENT_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.Status')
  sleep 5
done

# Get the imported snapshot ID
CONTENT_SNAPSHOT=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${CONTENT_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId')

echo "Content snapshot ID: ${CONTENT_SNAPSHOT}"

# Wait between import finish and register AMI
# running these too fast sometimes results in an error
sleep 5

# Register the AMI using the imported snapshot and get the new AMI ID
CONTENT_AMI=$(${EC2} register-image \
  --output text \
  --name "ocp4-${OCP_VER}-content" \
  --description "ocp4-${OCP_VER}-content" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"SnapshotId\":\"${CONTENT_SNAPSHOT}\",\"VolumeType\":\"${VOL_TYPE}\",\"DeleteOnTermination\":true}}]" \
  --root-device-name /dev/sda1)

echo "Content AMI: ${CONTENT_AMI}"

exit 0
