#!/bin/bash -xe

SNOWBALL_IP='192.168.1.240'
S3="aws --profile snowballEdge --region snow  --endpoint https://${SNOWBALL_IP}:8443 --ca-bundle /etc/pki/ca-trust/source/anchors/sbe.crt s3"
EC2="aws --profile snowballEdge --region snow --endpoint https://${SNOWBALL_IP}:8243 --ca-bundle /etc/pki/ca-trust/source/anchors/sbe.crt ec2"
BUCKET="redhat-dan"

IGN_CONFIGS='/home/danclark/openshift_clusters/snow/'
IGN_BASE='/home/danclark/openshift_clusters/install-config.yaml'

BOOTSTRAP_IMG='/opt/data/rhcos_4_6_8_bootstrap.img'
MASTER_IMG='/opt/data/rhcos_4_6_8_master.img'

RHCOS_VER='4.6.8'
OCP_VER='4.6.9'
PLATFORM='metal'
RHCOS_BASE_URL='https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.6/'


# Cleanup existing install dir
rm -rf "${IGN_CONFIGS}"

# Create install dir
mkdir "${IGN_CONFIGS}"

# Copy template install-config.yaml
cp "${IGN_BASE}" "${IGN_CONFIGS}/"

/usr/local/bin/openshift-install-4.6.9 create ignition-configs --dir="${IGN_CONFIGS}"

# Custom Networking
#filetranspiler -i ${IGN_CONFIGS=}/bootstrap.ign -f ${IGN_CONFIGS=}/../fakeroots/bootstrap --format json -o ${IGN_CONFIGS=}/bootstrap_custom.ign
#mv ${IGN_CONFIGS=}/bootstrap.ign ${IGN_CONFIGS=}/bootstrap.ign.orig
#mv ${IGN_CONFIGS=}/bootstrap_custom.ign ${IGN_CONFIGS=}/bootstrap.ign

#filetranspiler -i ${IGN_CONFIGS=}/master.ign -f ${IGN_CONFIGS=}/../fakeroots/master0 --format json -o ${IGN_CONFIGS=}/master_custom.ign
#mv ${IGN_CONFIGS=}/master.ign ${IGN_CONFIGS=}/master.ign.orig
#mv ${IGN_CONFIGS=}/master_custom.ign ${IGN_CONFIGS=}/master.ign

rm -f "${BOOTSTRAP_IMG}" "${MASTER_IMG}"
fallocate -l 16GB "${BOOTSTRAP_IMG}"
fallocate -l 16GB "${MASTER_IMG}"

sudo losetup -f -P "${BOOTSTRAP_IMG}"

sudo coreos-installer install --firstboot-args=console=tty0 --insecure --insecure-ignition \
  --preserve-on-error --platform "${PLATFORM}" \
  --image-url "${RHCOS_BASE_URL}/4.6.8/rhcos-4.6.8-x86_64-metal.x86_64.raw.gz" \
  --ignition-file "${IGN_CONFIGS}/bootstrap.ign" /dev/loop0

sudo sync

sudo losetup -d /dev/loop0

sudo losetup -f -P "${MASTER_IMG}"

sudo coreos-installer install --firstboot-args=console=tty0 --insecure --insecure-ignition \
  --preserve-on-error --platform "${PLATFORM}" \
  --image-url "${RHCOS_BASE_URL}/4.6.8/rhcos-4.6.8-x86_64-metal.x86_64.raw.gz" \
  --ignition-file "${IGN_CONFIGS}/master.ign" /dev/loop0

sudo sync

sudo losetup -d /dev/loop0

${S3} rm "s3://${BUCKET}/${BOOTSTRAP_IMG}"
${S3} rm "s3://${BUCKET}/${MASTER_IMG}"

##############################################
# Bootstrap Snapshot

${S3} cp "${BOOTSTRAP_IMG}" "s3://${BUCKET}/"

cat << EOF > /tmp/containers.json
{
    "Description": "Red Hat CoreOS 4.6.8 bootstrap platform aws",
    "Format": "RAW",
    "UserBucket": {
        "S3Bucket": "redhat-dan",
        "S3Key": "$(basename ${BOOTSTRAP_IMG})"
    }
}
EOF

BOOTSTRAP_IMPORT_ID=$( ${EC2} import-snapshot --disk-container "file:///tmp/containers.json" |  jq -r '.ImportTaskId')

echo "Bootstrap Snapshot import ID: ${BOOTSTRAP_IMPORT_ID}"

${S3} cp "${MASTER_IMG}" "s3://${BUCKET}/"

x="unknown"
while [[ "$x" != "completed" ]]
do
  echo "Waiting for bootstrap snapshot import to complete"
  x=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${BOOTSTRAP_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.Status')
  sleep 5
done

BOOTSTRAP_SNAPSHOT=$(${EC2} describe-import-snapshot-tasks --import-task-ids ${BOOTSTRAP_IMPORT_ID} | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId')

echo "Bootstrap snapshot ID: ${BOOTSTRAP_SNAPSHOT}"

#########################################################
# Master Snapshot
rm -f /tmp/containers.json

cat << EOF > /tmp/containers.json
{
    "Description": "Red Hat CoreOS 4.6.8 master platform aws",
    "Format": "RAW",
    "UserBucket": {
        "S3Bucket": "redhat-dan",
        "S3Key": "$(basename ${MASTER_IMG})"
    }
}
EOF

sleep 5

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

# RHCOS 4.6.8 bootstrap:
BOOTSTRAP_AMI=$(${EC2} register-image \
  --output text \
  --name rhcos-4.6.8-bootstrap \
  --description rhcos-4.6.8-bootstrap \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"SnapshotId\":\"${BOOTSTRAP_SNAPSHOT}\",\"VolumeType\":\"sbp1\",\"DeleteOnTermination\":true}}]" \
  --root-device-name /dev/sda1)

echo "Bootstrap AMI: ${BOOTSTRAP_AMI}"

# RHCOS 4.6.8 master:
MASTER_AMI=$(${EC2} register-image \
  --output text \
  --name rhcos-4.6.8-master \
  --description rhcos-4.6.8-master \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"SnapshotId\":\"${MASTER_SNAPSHOT}\",\"VolumeType\":\"sbp1\",\"DeleteOnTermination\":true}}]" \
  --root-device-name /dev/sda1)

echo "Master AMI: ${MASTER_AMI}"

sleep 5

BOOTSTRAP_INST_ID=$(${EC2} run-instances --image-id ${BOOTSTRAP_AMI} \
  --instance-type sbe-c.2xlarge | jq -r '.Instances[0].InstanceId')

#ec2 associate-address --public-ip 192.168.1.200 --instance-id 

MASTER0_INST_ID=$(${EC2} run-instances --image-id ${MASTER_AMI} \
  --instance-type sbe-c.2xlarge | jq -r '.Instances[0].InstanceId')

MASTER1_INST_ID=$(${EC2} run-instances --image-id ${MASTER_AMI} \
  --instance-type sbe-c.2xlarge | jq -r '.Instances[0].InstanceId')

MASTER2_INST_ID=$(${EC2} run-instances --image-id ${MASTER_AMI} \
  --instance-type sbe-c.2xlarge | jq -r '.Instances[0].InstanceId')

sleep 5

BOOTSTRAP_IP=$(${EC2} describe-instances --instance-ids ${BOOTSTRAP_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
MASTER0_IP=$(${EC2} describe-instances --instance-ids ${MASTER0_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
MASTER1_IP=$(${EC2} describe-instances --instance-ids ${MASTER1_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
MASTER2_IP=$(${EC2} describe-instances --instance-ids ${MASTER2_INST_ID} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

rm -f /tmp/snowdns.json
cat << EOF > /tmp/snowdns.json
{
  "Comment": "UPSERT OpenShift Records",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "bootstrap.snow.danclark.io.",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [{ "Value": "${BOOTSTRAP_IP}"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "master0.snow.danclark.io.",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [{ "Value": "${MASTER0_IP}"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "master1.snow.danclark.io.",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [{ "Value": "${MASTER1_IP}"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "master2.snow.danclark.io.",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [{ "Value": "${MASTER2_IP}"}]
      }
    }
  ]
}
EOF

BATCH=$(jq -c '.' /tmp/snowdns.json)

aws route53 change-resource-record-sets \
  --hosted-zone-id Z0893321IBKAQZL1S8ZE --change-batch "${BATCH}"


cat << EOF > /tmp/haproxy.cfg
global
  log /dev/log  local0
  log /dev/log  local1 notice
  stats socket /var/lib/haproxy/stats level admin
  chroot /var/lib/haproxy
  user haproxy
  group haproxy
  daemon

defaults
  mode                    http
  log                     global
  option                  httplog
  option                  dontlognull
  option http-server-close
  option forwardfor       except 127.0.0.0/8
  option                  redispatch
  retries                 3
  timeout http-request    10s
  timeout queue           1m
  timeout connect         10s
  timeout client          1m
  timeout server          1m
  timeout http-keep-alive 10s
  timeout check           10s
  maxconn                 3000

#---------------------------------------------------------------------
listen stats
    bind :9000
    mode http
    stats enable
    stats uri /
    monitor-uri /healthz

frontend openshift-api-server
    bind *:6443
    default_backend openshift-api-server
    mode tcp
    option tcplog

backend openshift-api-server
    balance source
    mode tcp
    server bootstrap ${BOOTSTRAP_IP}:6443 check
    server master0 ${MASTER0_IP}:6443 check
    server master1 ${MASTER1_IP}:6443 check
    server master2 ${MASTER2_IP}:6443 check

frontend machine-config-server
    bind *:22623
    default_backend machine-config-server
    mode tcp
    option tcplog

backend machine-config-server
    balance source
    mode tcp
    server bootstrap ${BOOTSTRAP_IP}:22623 check
    server master0 ${MASTER0_IP}:22623 check
    server master1 ${MASTER1_IP}:22623 check
    server master2 ${MASTER2_IP}:22623 check

frontend ingress-http
    bind *:80
    default_backend ingress-http
    mode tcp
    option tcplog

backend ingress-http
    balance source
    mode tcp
    server master0 ${MASTER0_IP}:80 check
    server master1 ${MASTER1_IP}:80 check
    server master2 ${MASTER2_IP}:80 check

frontend ingress-https
    bind *:443
    default_backend ingress-https
    mode tcp
    option tcplog

backend ingress-https
    balance source
    mode tcp
    server master0 ${MASTER0_IP}:443 check
    server master1 ${MASTER1_IP}:443 check
    server master2 ${MASTER2_IP}:443 check

#---------------------------------------------------------------------
EOF

scp -i ~/.ssh/danclark-personal.pem /tmp/haproxy.cfg ec2-user@192.168.1.183:
ssh -i ~/.ssh/danclark-personal.pem ec2-user@192.168.1.183 sudo mv /home/ec2-user/haproxy.cfg /etc/haproxy/haproxy.cfg
ssh -i ~/.ssh/danclark-personal.pem ec2-user@192.168.1.183 sudo chown root.root /etc/haproxy/haproxy.cfg
ssh -i ~/.ssh/danclark-personal.pem ec2-user@192.168.1.183 sudo systemctl restart haproxy
scp -i ~/.ssh/danclark-personal.pem /home/danclark/openshift_clusters/snow/auth/kubeconfig ec2-user@192.168.1.183:/home/ec2-user/.kube/config

