SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Script to take in
# - SBE API Endpoint
# - Location of Manifest File
# - SBE Unlock Code

read -p "Enter SnowBall Edge API Endpoint IP Address:  " endpoint
read -p "Enter path to manifest file: " manifest
read -p "Enter Unlock Code: " unlock

if ! ping -c 1 "${endpoint}" 2>&1 > /dev/null
then
  echo "Endpoint IP Address unreachable, please retry"
  exit 1
fi

if ! test -f "${manifest}"
then
  echo "${manifest} file not found, please retry"
  exit 1
fi

sed -i "s|export ENDPOINT=.*|export ENDPOINT=\"$endpoint\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export MANIFEST=.*|export MANIFEST=\"$manifest\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export UNLOCK=.*|export UNLOCK=\"$unlock\"|" "${SCRIPT_DIR}/env.sh"

# Now that the vars above are set, resource env file
source "${SCRIPT_DIR}/env.sh"

echo "Installing snowball edge certificate authority on system"

# List available certificates on the snowcone
CERT_ARN=$(snowballEdge list-certificates ${OPTS} | jq -r '.Certificates[0].CertificateArn')

# Export the snowcone certificates
snowballEdge get-certificate ${OPTS} --certificate-arn ${CERT_ARN} > snow_cert.pem

DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
if [[ "${DISTRO}" =~ 'Fedora' || "${DISTRO}" =~ 'RHEL' || "${DISTRO}" =~ 'CentOS' ]]
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

# Configure the EC2 and S3 port numbers
ec2_port=$(snowballEdge describe-service ${OPTS} --service-id ec2 | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')
s3_port=$(snowballEdge describe-service ${OPTS} --service-id s3 | jq -c -r '.Endpoints[] | select(.Protocol=="https").Port')

sed -i "s|export EC2_PORT=.*|export EC2_PORT=\"$ec2_port\"|" "${SCRIPT_DIR}/env.sh"

sed -i "s|export S3_PORT=.*|export S3_PORT=\"$s3_port\"|" "${SCRIPT_DIR}/env.sh"

exit 0
