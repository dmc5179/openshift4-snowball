#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

function usage {

  echo "$0 <s3_bucket> <path_to_ami_raw_disk_file_in_s3_bucket>"

}

# Check that the S3 bucket and S3 path options have been passed in
if [ "$#" -ne 2 ]
then
  echo "Usage: $0 <s3_bucket> <s3_path_to_file>"
  exit 1
fi

S3_BUCKET=${1}
S3_PATH=${2}

##############################################
# RHCOS Snapshot

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

CONTENT_IMPORT_ID=$( ${EC2} import-snapshot --disk-container "file:///tmp/containers.json" |  jq -r '.ImportTaskId')

echo "Content Snapshot import ID: ${CONTENT_IMPORT_ID}"

x="unknown"
while [[ "$x" != "completed" ]]
do
  echo "Waiting for snapshot import to complete"
  x=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${CONTENT_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.Status')
  sleep 5
done

CONTENT_SNAPSHOT=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${CONTENT_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId')

echo "Content snapshot ID: ${CONTENT_SNAPSHOT}"

sleep 5

# Register the AMI
CONTENT_AMI=$(${EC2} register-image \
  --output text \
  --name "ocp4-${OCP_VER}-content" \
  --description "ocp4-${OCP_VER}-content" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"SnapshotId\":\"${CONTENT_SNAPSHOT}\",\"VolumeType\":\"sbp1\",\"DeleteOnTermination\":true}}]" \
  --root-device-name /dev/sda1)

echo "Content AMI: ${CONTENT_AMI}"

exit 0
