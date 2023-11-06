
# This script file is not meant to be run directly
# It is sourced by other scripts in this repo

###########################################################
# These will be updated by running the configure.sh script
export ENDPOINT=""
export MANIFEST=""
export UNLOCK=""
export CA_BUNDLE=""
export EC2_PORT=""
export S3_PORT=""
export S3_BUCKET=""
export SSH_KEY=""
# IPs should map to VNIs on the SBE
export BOOTSTRAP_IP=""
export MASTER0_IP=""
export MASTER1_IP=""
export MASTER2_IP=""
export BASE_DOMAIN=""
export CLUSTER_NAME=""
###########################################################
# These will be updated by running the import_rhcos_ami.sh script
export RHCOS_BASE_AMI_ID=""
###########################################################
# These are composed of the above vars. Do not edit
export OPTS="--endpoint https://${ENDPOINT} --manifest-file ${MANIFEST} --unlock-code ${UNLOCK}"

export S3="aws --profile snowballEdge --region snow  --endpoint https://${ENDPOINT}:${S3_PORT} --ca-bundle ${CA_BUNDLE} s3"

export EC2="aws --profile snowballEdge --region snow --endpoint https://${ENDPOINT}:${EC2_PORT} --ca-bundle ${CA_BUNDLE} ec2"

alias ec2="aws --profile snowballEdge --region snow  --endpoint https://${ENDPOINT}:${EC2_PORT} --ca-bundle ${CA_BUNDLE} ec2"

alias s3="aws --profile snowballEdge --region snow  --endpoint https://${ENDPOINT}:${S3_PORT} --ca-bundle ${CA_BUNDLE} s3"
############################################################
#TODO May not actually need these anymore
export RHCOS_VER='4.13.10'
export OCP_VER='4.13.10'
export PLATFORM='metal'
export RHCOS_BASE_URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos"
#############################################################
