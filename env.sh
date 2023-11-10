
# This script file is not meant to be run directly
# It is sourced by other scripts in this repo

###########################################################
# These will be updated by running the configure.sh script
###############################################
# API Endpoint IP addresses
export SBE_ENDPOINT=""
export NON_S3_ENDPOINT=""
export S3_BUCKET_ENDPOINT=""
export S3_OBJECT_ENDPOINT=""
##########################################
export MANIFEST=""
export UNLOCK=""
export CA_BUNDLE=""
######################################
# API Endpoint Ports
export EC2_PORT=""
export STS_PORT=""
export IAM_PORT=""
export SSM_PORT=""
export S3_BUCKET_PORT=""
export S3_OBJECT_PORT=""
######################################
export S3_BUCKET=""
export SSH_KEY=""
# IPs should map to VNIs on the SBE
# OpenShift cluster node IP addresses
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
export SBE_OPTS="--endpoint https://${SBE_ENDPOINT} --manifest-file ${MANIFEST} --unlock-code ${UNLOCK}"

# EC2
export EC2="aws --profile snowballEdge --region snow --endpoint https://${NON_S3_ENDPOINT}:${EC2_PORT} --ca-bundle ${CA_BUNDLE} ec2"
alias ec2="aws --profile snowballEdge --region snow  --endpoint https://${NON_S3_ENDPOINT}:${EC2_PORT} --ca-bundle ${CA_BUNDLE} ec2"

# IAM
export IAM="aws --profile snowballEdge --region snow --endpoint https://${NON_S3_ENDPOINT}:${IAM_PORT} --ca-bundle ${CA_BUNDLE} iam"
alias iam="aws --profile snowballEdge --region snow  --endpoint https://${NON_S3_ENDPOINT}:${IAM_PORT} --ca-bundle ${CA_BUNDLE} iam"

# SSM
export SSM="aws --profile snowballEdge --region snow --endpoint https://${NON_S3_ENDPOINT}:${SSM_PORT} --ca-bundle ${CA_BUNDLE} ssm"
alias ssm="aws --profile snowballEdge --region snow  --endpoint https://${NON_S3_ENDPOINT}:${SSM_PORT} --ca-bundle ${CA_BUNDLE} ssm"

# STS
export STS="aws --profile snowballEdge --region snow --endpoint https://${NON_S3_ENDPOINT}:${STS_PORT} --ca-bundle ${CA_BUNDLE} sts"
alias sts="aws --profile snowballEdge --region snow  --endpoint https://${NON_S3_ENDPOINT}:${STS_PORT} --ca-bundle ${CA_BUNDLE} sts"

# S3 Bucket
export S3_BUCKET="aws --profile snowballEdge --region snow  --endpoint https://${S3_BUCKET_ENDPOINT}:${S3_BUCKET_PORT} --ca-bundle ${CA_BUNDLE} s3"
alias s3_bucket="aws --profile snowballEdge --region snow  --endpoint https://${S3_BUCKET_ENDPOINT}:${S3_BUCKET_PORT} --ca-bundle ${CA_BUNDLE} s3"

# S3 Object
export S3_OBJECT="aws --profile snowballEdge --region snow  --endpoint https://${S3_OBJECT_ENDPOINT}:${S3_OBJECT_PORT} --ca-bundle ${CA_BUNDLE} s3"
alias s3_object="aws --profile snowballEdge --region snow  --endpoint https://${S3_OBJECt_ENDPOINT}:${S3_OBJECT_PORT} --ca-bundle ${CA_BUNDLE} s3"

############################################################
#TODO May not actually need these anymore
export RHCOS_VER='4.13.10'
export OCP_VER='4.13.10'
export PLATFORM='metal'
export RHCOS_BASE_URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos"
#############################################################
