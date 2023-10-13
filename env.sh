export SNOWBALL_IP='192.168.1.240'

export S3="aws --profile snowballEdge --region snow  --endpoint https://${SNOWBALL_IP}:8443 --ca-bundle /etc/pki/ca-trust/source/anchors/sbe.crt s3"
export EC2="aws --profile snowballEdge --region snow --endpoint https://${SNOWBALL_IP}:8243 --ca-bundle /etc/pki/ca-trust/source/anchors/sbe.crt ec2"
export BUCKET="redhat-dan"

export RHCOS_VER='4.13.10'
export OCP_VER='4.13.10'
export PLATFORM='metal'
export RHCOS_BASE_URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos"

