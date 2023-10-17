#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

# Get the RHCOS image name
RHCOS_IMG=$(ls -1 /opt/openshift/rhcos/rhcos*)

extension=${RHCOS_IMG##*.}

# If the file is compressed, decompress it and change file var
if [[ "${extension}" == "gz" ]]
then
  gunzip "${RHCOS_IMG}"
  RHCOS_IMG="${RHCOS_IMG%.*}"
fi

echo ${RHCOS_IMG}

##############################################
# RHCOS Snapshot

echo "Uploading decompressed RHCOS disk image to SBE S3"
${S3} cp "${RHCOS_IMG}" "s3://${S3_BUCKET}/"

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
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"SnapshotId\":\"${RHCOS_SNAPSHOT}\",\"VolumeType\":\"sbp1\",\"DeleteOnTermination\":true}}]" \
  --root-device-name /dev/sda1)

echo "RHCOS AMI: ${RHCOS_AMI}"

exit 0
