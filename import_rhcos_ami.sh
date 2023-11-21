#!/bin/bash -xe

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

# Get the RHCOS VMDK compressed image name
RHCOS_VMDK_GZ=$(ls -1 /opt/openshift/rhcos/rhcos*.vmdk.gz)
# Get the RHCOS VMDK image name
RHCOS_VMDK="${RHCOS_VMDK_GZ%.*}"

# Decompress without losing the original file in case this script needs to be rerun
gunzip -c "${RHCOS_VMDK_GZ}" > "${RHCOS_VMDK}"

RHCOS_IMG="${RHCOS_VMDK%.*}.img"

# Convert RHCOS VMDK into RAW disk
# SBE only allows import of RAW disks
qemu-img convert -f vmdk -O raw ${RHCOS_VMDK} ${RHCOS_IMG}

# Remove VMDK file
rm -f "${RHCOS_VMDK}"

# Increase size of disk to 75 GBs
qemu-img resize -f raw "${RHCOS_IMG}" +50G

# Mount IMG as loopback
sudo losetup -D
sudo losetup -f -P "${RHCOS_IMG}"

# Fix the GPT partition table now that the disk has been resized
printf "fix\n" | sudo parted ---pretend-input-tty /dev/loop0 print

# Increase partition #4 to new size
sudo parted -s /dev/loop0 resizepart 4 100%

# Discover partitions inside IMG file
sudo kpartx -av ${RHCOS_IMG}

# Mount root partition from IMG file
if ! test -d /mnt/rhcos; then sudo mkdir /mnt/rhcos; fi
sudo mount /dev/mapper/loop0p4 /mnt/rhcos

# Grow XFS Root partition
sudo xfs_growfs /mnt/rhcos

# Unmount
sudo umount /mnt/rhcos

# Remove discovered partitions
sudo kpartx -dv ${RHCOS_IMG}

# Ensure loop device is unmounted
sudo losetup -D

##############################################
# RHCOS Snapshot

echo "Uploading decompressed RHCOS disk image to SBE S3"
${S3_OBJECT} cp "${RHCOS_IMG}" "s3://${S3_BUCKET}/"

# Remove the local RHCOS disk image file after s3 upload
rm -f "${RHCOS_IMG}"

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
sed -i "s|RHCOS_BASE_AMI_ID=.*|RHCOS_BASE_AMI_ID=${RHCOS_AMI}|" env.sh

echo "RHCOS AMI: ${RHCOS_AMI}"

exit 0
