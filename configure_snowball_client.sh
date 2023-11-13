SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Script to take in
# - SBE API Endpoint
# - Location of Manifest File
# - SBE Unlock Code

read -p "Enter SnowBall Edge API Endpoint IP Address:  " sbe_endpoint
read -p "Enter path to manifest file: " manifest
read -p "Enter Unlock Code: " unlock

if ! ping -c 1 "${sbe_endpoint}" 2>&1 > /dev/null
then
  echo "Endpoint IP Address unreachable, please retry"
  exit 1
fi

if ! test -f "${manifest}"
then
  echo "${manifest} file not found, please retry"
  exit 1
fi

sed -i "s|export SBE_ENDPOINT=.*|export SBE_ENDPOINT=\"$sbe_endpoint\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export MANIFEST=.*|export MANIFEST=\"$manifest\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export UNLOCK=.*|export UNLOCK=\"$unlock\"|" "${SCRIPT_DIR}/env.sh"

# Now that the vars above are set, resource env file
source "${SCRIPT_DIR}/env.sh"

echo "Installing snowball edge certificate authority on system"

# List available certificates on the snowcone
CERT_ARN=$(snowballEdge list-certificates ${SBE_OPTS} | jq -r '.Certificates[0].CertificateArn')

# Export the snowcone certificates
snowballEdge get-certificate ${SBE_OPTS} --certificate-arn ${CERT_ARN} > snow_cert.pem

DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
if [[ "${DISTRO}" =~ 'Fedora' || "${DISTRO}" =~ 'RHEL' || "${DISTRO}" =~ 'CentOS' || "${DISTRO}" =~ 'Red Hat' ]]
then
  ca_bundle="/etc/pki/ca-trust/source/anchors/snow_cert.pem"
  # Add snowcone certificate to the system trust store and update
  sudo mv snow_cert.pem "${ca_bundle}"
  sudo chown root.root "${ca_bundle}"
  sudo chmod 0444 "${ca_bundle}"
  sudo restorecon "${ca_bundle}"
  sudo update-ca-trust
  sudo update-ca-trust extract
elif [[ "${DISTRO}" =~ 'Ubuntu' ]]
then
  ca_bundle="/usr/local/share/ca-certificates/snow_cert.pem"
  sudo mv snow_cert.pem "${ca_bundle}"
  sudo chown root.root "${ca_bundle}"
  sudo chmod 0444 "${ca_bundle}"
  sudo update-ca-certificates
else
  echo 'Unable to add snowball pem to system trust store. Needs to be done manually'
  ca_bundle="${PWD}/snow_cert.pem"
fi

sed -i "s|export CA_BUNDLE=.*|export CA_BUNDLE=\"$ca_bundle\"|" "${SCRIPT_DIR}/env.sh"

########################################################
# Configure service IP addresses
# TODO: Make the jq select pattern more forgiving as the descriptions may change
non_s3_endpoint=$(snowballEdge describe-service ${SBE_OPTS} --service-id ec2 | jq -c -r '.Endpoints[] | select(.Protocol=="https").Host')
s3_bucket_endpoint=$(snowballEdge describe-service ${SBE_OPTS} --service-id s3-snow | jq -r -c '.Endpoints[] | select(.Description=="s3-snow bucket API endpoint").Host')
s3_object_endpoint=$(snowballEdge describe-service ${SBE_OPTS} --service-id s3-snow | jq -r -c '.Endpoints[] | select(.Description=="s3-snow object API endpoint").Host')

sed -i "s|export NON_S3_ENDPOINT=.*|export NON_S3_ENDPOINT=\"$non_s3_endpoint\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export S3_BUCKET_ENDPOINT=.*|export S3_BUCKET_ENDPOINT=\"$s3_bucket_endpoint\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export S3_OBJECT_ENDPOINT=.*|export S3_OBJECT_ENDPOINT=\"$s3_object_endpoint\"|" "${SCRIPT_DIR}/env.sh"

#######################################################################################################
# Configure the EC2 and S3 port numbers
ec2_port=$(snowballEdge describe-service ${SBE_OPTS} --service-id ec2 | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')
sts_port=$(snowballEdge describe-service ${SBE_OPTS} --service-id sts | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')
iam_port=$(snowballEdge describe-service ${SBE_OPTS} --service-id iam | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')
ssm_port=$(snowballEdge describe-service ${SBE_OPTS} --service-id ssm | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')
s3_bucket_port=$(snowballEdge describe-service ${SBE_OPTS} --service-id s3-snow | jq -r -c '.Endpoints[] | select(.Description=="s3-snow bucket API endpoint").Port')
s3_object_port=$(snowballEdge describe-service ${SBE_OPTS} --service-id s3-snow | jq -r -c '.Endpoints[] | select(.Description=="s3-snow object API endpoint").Port')

# Replace vars in the env.sh file
sed -i "s|export EC2_PORT=.*|export EC2_PORT=\"$ec2_port\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export STS_PORT=.*|export STS_PORT=\"$sts_port\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export IAM_PORT=.*|export IAM_PORT=\"$iam_port\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export SSM_PORT=.*|export SSM_PORT=\"$ssm_port\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export S3_BUCKET_PORT=.*|export S3_BUCKET_PORT=\"$s3_bucket_port\"|" "${SCRIPT_DIR}/env.sh"
sed -i "s|export S3_OBJECT_PORT=.*|export S3_OBJECT_PORT=\"$s3_object_port\"|" "${SCRIPT_DIR}/env.sh"

exit 0
























