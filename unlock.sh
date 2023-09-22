#!/bin/bash

# example script to unlock and configure the snowball itself

# Unlock the device, this requires the manifest and unlock code from AWS
snowballEdge unlock-device

# Determine the interface id of the physical network adapter
NIC_ID=$(snowballEdge describe-device | jq -r -c '.PhysicalNetworkInterfaces[0].PhysicalNetworkInterfaceId')

# Create a virtual network adapter to attach to EC2 instances
snowballEdge create-virtual-network-interface --ip-address-assignment dhcp --physical-network-interface-id "${NIC_ID}"

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

snowballEdge start-service --service-id service_id --virtual-network-interface-arns virtual-network-interface-arn

# List access keys
snowballEdge list-access-keys

# Get secret key associated with access key above
snowballEdge get-secret-access-key --access-key-id "access_key from above command"

# Create a key-pair for instances to use
snow create-key-pair --key-name danclark-snowcone

# creating the key pair prints out in json. Convert that to your SSH RSA key file

# Describe available AMIs
snow describe-images

# Launch and instance
#snc1.micro (1 CPU and 1 GB RAM), snc1.small (1 CPU and 2 GB RAM), and snc1.medium (2 CPU and 4 GB RAM).
snow run-instances --image-id s.ami-019808f1c0995a94a --key-name danclark-snowcone --instance-type snc1.medium

# Attach the virtual network device to the instance. Need to wait until the instance is in the right state
snow associate-address --public-ip 192.168.1.174 --instance-id s.i


