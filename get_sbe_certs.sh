#!/bin/bash

# List available certificates on the snowcone
snowballEdge list-certificates

# Export the snowcone certificates
# example arn: arn:aws:snowball-device:::certificate/123456789
snowballEdge get-certificate --certificate-arn "arn from list-certificates command" > snowcone_cert.pem

# Add snowcone certificate to the system trust store and update
sudo cp snowcone_cert.pem /etc/pki/ca-trust/source/anchors/snowcone_cert.pem
sudo chown root.root /etc/pki/ca-trust/source/anchors/snowcone_cert.pem
sudo chmod 0644 /etc/pki/ca-trust/source/anchors/snowcone_cert.pem
sudo restorecon -v /etc/pki/ca-trust/source/anchors/snowcone_cert.pem
sudo update-ca-trust
sudo update-ca-trust extract
