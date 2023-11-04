#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

OPTS="--endpoint https://${ENDPOINT} --manifest-file ${MANIFEST} --unlock-code ${UNLOCK}"

# List available certificates on the snowcone
CERT_ARN=$(snowballEdge list-certificates ${OPTS} | jq -r '.Certificates[0].CertificateArn')

# Export the snowcone certificates
snowballEdge get-certificate ${OPTS} --certificate-arn ${CERT_ARN} > snow_cert.pem

# Add snowcone certificate to the system trust store and update
sudo cp snow_cert.pem /etc/pki/ca-trust/source/anchors/snow_cert.pem
sudo chown root.root /etc/pki/ca-trust/source/anchors/snow_cert.pem
sudo chmod 0444 /etc/pki/ca-trust/source/anchors/snow_cert.pem
sudo restorecon -v /etc/pki/ca-trust/source/anchors/snow_cert.pem
sudo update-ca-trust
sudo update-ca-trust extract

exit 0
