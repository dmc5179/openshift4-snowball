#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

# Get the RHCOS image name
RHCOS_VMDK=$(ls -1 /opt/openshift/rhcos/rhcos*.vmdk.gz)

extension=${RHCOS_VMDK##*.}

# If the file is compressed, decompress it and change file var
if [[ "${extension}" == "gz" ]]
then
  gunzip "${RHCOS_VMDK}"
  RHCOS_VMDK="${RHCOS_IMG%.*}"
fi

RHCOS_IMG="${RHCOS_IMG%.*}.img"

# Convert RHCOS VMDK into RAW disk
# SBE only allows import of RAW disks
qemu-img convert -f vmdk -O raw ${RHCOS_VMDK} ${RHCOS_IMG}

# Increase size of disk to 75 GBs
qemu-img resize -f raw "${RHCOS_IMG}" +50G

# Mount IMG as loopback
sudo losetup -D
sudo losetup -f -P "${RHCOS_IMG}"

# Increase partition #4 to new size
parted -s /dev/loop0 resizepart 4 100%

# Discover partitions inside IMG file
sudo kpartx -av disk_image.raw 

# Mount root partition from IMG file
sudo mount /dev/mapper/.... /mnt/rhcos

# Grow XFS Root partition
xfs_growfs /mnt/rhcos

# Unmount
sudo umount /mnt/rhcos
sudo losetup -D

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

# Update the env script to have the new AMI ID
sed -i "s|SBE-AMI|${RHCOS_AMI}|" env.sh

echo "RHCOS AMI: ${RHCOS_AMI}"

exit 0
