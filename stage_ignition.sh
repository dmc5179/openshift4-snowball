#!/bin/bash -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

#${S3} cp /opt/openshift/cluster/bootstrap.ign "s3://${S3_BUCKET}/ignition/"
#${S3} cp /opt/openshift/cluster/master.ign "s3://${S3_BUCKET}/ignition/"
#${S3} cp /opt/openshift/cluster/worker.ign "s3://${S3_BUCKET}/ignition/"

sudo cp /opt/openshift/cluster/*.ign /var/www/html/ignition/
sudo chown root.root /var/www/html/ignition/*.ign
sudo chmod 0444 /var/www/html/ignition/*.ign
sudo restorecon -v /var/www/html/ignition/*.ign


