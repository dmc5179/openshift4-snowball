# openshift4-snowball

- Start by running the unlock command on the SBE. This requires the manifest and unlock code from AWS
```
snowballEdge unlock-device
```

- Determine the interface id of the physical network adapter
```
NIC_ID=$(snowballEdge describe-device | jq -r -c '.PhysicalNetworkInterfaces[0].PhysicalNetworkInterfaceId')
echo ${NIC_ID}
```

- Create a virtual network adapter to attach to EC2 instances. This example uses DHCP. See command options for static IP assignment
```
snowballEdge create-virtual-network-interface --ip-address-assignment dhcp --physical-network-interface-id "${NIC_ID}"
```

- Run the get_sbe_certs.sh to download the Certificate Authority from the SBE and install it on the local system
```
get_sbe_certs.sh
```

- Get the virtual network interface ARN
```
```

- Start the ec2 and s3 services on the Snowball Device
```
snowballEdge start-service --service-id ec2 --virtual-network-interface-arns virtual-network-interface-arn
snowballEdge start-service --service-id s3 --virtual-network-interface-arns virtual-network-interface-arn
```

- List the API keys included with the SBE
```
snowballEdge list-access-keys
```

- Get secret key associated with access key above
```
snowballEdge get-secret-access-key --access-key-id "access_key from above command"
```

- Create a key-pair for instances to use
```
snow create-key-pair --key-name <my_key_name>
```

- It is a good idea to alias the ec2 and s3 commands as the required options are long. Note that the services run on different ports. Include the IP address of the SBE itself.
```
alias s3="aws --profile snowballEdge --region snow  --endpoint https://< SNOWBALL_IP >:8443 --ca-bundle /etc/pki/ca-trust/source/anchors/snow_cert.pem s3"
alias ec2="aws --profile snowballEdge --region snow --endpoint https://< SNOWBALL_IP >:8243 --ca-bundle /etc/pki/ca-trust/source/anchors/snow_cert.pem ec2"
```

- Run the following script to load the OpenShift Content AMI from S3 on the SBE into EC2 on the SBE
```
import_content_ami.sh <s3_bucket> <s3_path>
```

- Launch the OpenShift Content AMI as an EC2 Instance from outside the snowball device
```
snow run-instances --image-id <Content_AMI_ID> --key-name <my_key_name> --instance-type sbe-c.2xlarge

snow associate-address --public-ip <IP to assign> --instance-id <Content_Instance_ID>
```

- Copy the SnowBall Edge Manifest to the Content Instance.

- Login to the Content Instance running on the SBE

- Change directories into the openshift4-snowball directory
```
cd /home/ec2-user/openshift4-snowball
```

- Run the following script to configure the snowballEdge client
```
./configure_snowball_client.sh
```

- Run the following script to configure the environment
```
./configure.sh
```

- Run the following script to load the RHCOS disk image into the SBE
```
import_rhcos_ami.sh
```

- Run the following script to setup the environment
```
./setup.sh
```

- Run the following script to deploy the OpenShift cluster
```
./deploy_openshift.sh
```
