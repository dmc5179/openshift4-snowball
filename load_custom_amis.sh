#!/bin/bash 

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

BOOTSTRAP_IMG='/opt/openshift/bootstrap.img'
MASTER_IMG='/opt/openshift/master.img'

# Detach all loop devices
sudo losetup -D

rm -f "${BOOTSTRAP_IMG}" "${MASTER_IMG}"

fallocate -l 16GB "${BOOTSTRAP_IMG}"
fallocate -l 16GB "${MASTER_IMG}"

#######################

sudo losetup -f -P "${BOOTSTRAP_IMG}"

sudo /usr/local/bin/coreos-installer install --firstboot-args=console=tty0 --insecure --insecure-ignition \
  --preserve-on-error --platform "metal" --offline \
  --image-file '/opt/openshift/rhcos/rhcos-4.13.10-x86_64-metal.x86_64.raw.gz' \
  --ignition-file "/opt/openshift/cluster/bootstrap.ign" /dev/loop0

sudo sync

sudo losetup -D

#######################

sudo losetup -f -P "${MASTER_IMG}"

sudo /usr/local/bin/coreos-installer install --firstboot-args=console=tty0 --insecure --insecure-ignition \
  --preserve-on-error --platform "metal" --offline \
  --image-file '/opt/openshift/rhcos/rhcos-4.13.10-x86_64-metal.x86_64.raw.gz' \
  --ignition-file "/opt/openshift/cluster/master.ign" /dev/loop0

sudo sync

sudo losetup -D

##############################

${S3} rm "s3://${S3_BUCKET}/${BOOTSTRAP_IMG}"
${S3} rm "s3://${S3_BUCKET}/${MASTER_IMG}"

${S3} cp "${BOOTSTRAP_IMG}" "s3://${S3_BUCKET}/"
${S3} cp "${MASTER_IMG}" "s3://${S3_BUCKET}/"

#########################################################
# Creating bootstrap AMI

rm -f /tmp/containers.json

cat << EOF > /tmp/containers.json
{ 
    "Description": "Red Hat CoreOS ${RHCOS_VER} Bootstrap",
    "Format": "RAW",
    "UserBucket": {
        "S3Bucket": "${S3_BUCKET}",
        "S3Key": "$(basename ${BOOTSTRAP_IMG})"
    }
}
EOF

BOOTSTRAP_IMPORT_ID=$( ${EC2} import-snapshot --disk-container "file:///tmp/containers.json" |  jq -r '.ImportTaskId')

echo "Bootstrap Snapshot import ID: ${BOOTSTRAP_IMPORT_ID}"

x="unknown"
while [[ "$x" != "completed" ]]
do
  echo "Waiting for bootstrap snapshot import to complete"
  x=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${BOOTSTRAP_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.Status')
  sleep 5
done

BOOTSTRAP_SNAPSHOT=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${BOOTSTRAP_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId')

echo "Bootstrap snapshot ID: ${BOOTSTRAP_SNAPSHOT}"

sleep 5

# Register the AMI
export BOOTSTRAP_AMI=$(${EC2} register-image \
  --output text \
  --name "rhcos-${RHCOS_VER}-bootstrap" \
  --description "rhcos-${RHCOS_VER}-bootstrap" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"SnapshotId\":\"${BOOTSTRAP_SNAPSHOT}\",\"VolumeType\":\"sbp1\",\"DeleteOnTermination\":true}}]" \
  --root-device-name /dev/sda1)

echo "Bootstrap AMI: ${BOOTSTRAP_AMI}"
#############################################################
# Creating Master AMI

rm -f /tmp/containers.json

cat << EOF > /tmp/containers.json
{ 
    "Description": "Red Hat CoreOS ${RHCOS_VER} Master",
    "Format": "RAW",
    "UserBucket": {
        "S3Bucket": "${S3_BUCKET}",
        "S3Key": "$(basename ${MASTER_IMG})"
    }
}
EOF

MASTER_IMPORT_ID=$( ${EC2} import-snapshot --disk-container "file:///tmp/containers.json" |  jq -r '.ImportTaskId')

echo "Master Snapshot import ID: ${MASTER_IMPORT_ID}"

x="unknown"
while [[ "$x" != "completed" ]]
do
  echo "Waiting for master snapshot import to complete"
  x=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${MASTER_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.Status')
  sleep 5
done

MASTER_SNAPSHOT=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${MASTER_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId')

echo "Master snapshot ID: ${MASTER_SNAPSHOT}"

sleep 5

# Register the AMI
export MASTER_AMI=$(${EC2} register-image \
  --output text \
  --name "rhcos-${RHCOS_VER}-master" \
  --description "rhcos-${RHCOS_VER}-master" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"SnapshotId\":\"${MASTER_SNAPSHOT}\",\"VolumeType\":\"sbp1\",\"DeleteOnTermination\":true}}]" \
  --root-device-name /dev/sda1)

echo "Master AMI: ${MASTER_AMI}"

