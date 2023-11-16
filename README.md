# openshift4-snowball

Tools to deploy OpenShift 4 on an AWS Snowball Edge Device

# Table of Contents

   * [Configure SBE External Host](#configure-external-host)
     * [Unlock](#unlock)
     * [Connect SBE to your network](#connect)
     * [Start SBE Services](#start-sbe-services)
     * [Extract AWS API Keys](#extract)
     * [Create EC2 Keypair](#keypair)
     * [Configure SBE Client](#client-configure)
   * [Import OpenShift Content AMI](#import-content-ami)
   * [Deploying OpenShift to the SBE](#deploy-openshift)
     * [Configure Snowball Client on the Content Instance](#content-client-configure)
     * [Configure Environemt on the Content Instance](#content-environment)
     * [Import Red Hat Core OS (RHCOS) AMI](#import-rhcos)
     * [Deploy Required services on the Content Instance](#deploy-servies)
     * [Deploy OpenShift Cluster](#deploy-openshift)

# Configuring SBE External Host

This section details how to configure a RHEL machine that is external to the Snowball Edge (SBE) device. The SBE external host will be used to initialize the SBE and import the OpenShift content AMI used to deploy the OpenShift cluster.

## Unlock

Use the following commands to unlock the AWS Snowball Edge (SBE) and attach it to your network. These commands are run from a host external to the SBE and have been tested on a RHEL system.

- Start by running the unlock command on the SBE. This requires the manifest and unlock code from AWS
```
snowballEdge unlock-device --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE>
```

## Connect SBE to your network

- Determine the interface id of the physical network adapter
```
NIC_ID=$(snowballEdge describe-device --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE> | jq -r -c '.PhysicalNetworkInterfaces[0].PhysicalNetworkInterfaceId')
echo ${NIC_ID}
```

- Create a virtual network adapter to attach to EC2 instances. This example uses DHCP. See snowballEdge command options for static IP assignment.
```
snowballEdge create-virtual-network-interface --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE> --ip-address-assignment dhcp --physical-network-interface-id "${NIC_ID}"
```

## Start the EC2 and S3 services on the SBE

- Start the ec2 and s3 services on the Snowball Device using the virtual network interface created above.
```
snowballEdge start-service --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE> --service-id ec2 --virtual-network-interface-arns <virtual-network-interface-arn>

snowballEdge start-service --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE> --service-id s3 --virtual-network-interface-arns >virtual-network-interface-arn>
```

## Extract AWS API Keys

- List the API keys included with the SBE
```
snowballEdge  list-access-keys --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE>
```

- Get secret key associated with access key above
```
snowballEdge get-secret-access-key --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE> --access-key-id "access_key from above command"
```

- Configure the snowballEdge AWS CLI profile. Enter the access keys from the above command, region as snow, output as json.
```
aws --profile snowballEdge configure
```

## Create EC2 Keypair

- Create a key-pair for instances to use
```
snowballEdge create-key-pair --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE> --key-name <my_key_name>
```

## Configure SBE client

- Run the configure_snowball_client.sh command to configure the client. This must be done after the EC2 and S3 services have been started to extract the ports those services are running on.
```
configure_snowball_client.sh
```

# Import OpenShift Content AMI

The OpenShift Content AMI is shipped with the SBE as a disk image located in S3 on the SBE. It must be imported into the SBE as an EC2 AMI

- Run the following script to load the OpenShift Content AMI from S3 on the SBE into EC2 on the SBE. The options are the S3 bucket and path where the disk image is located inside the SBE.
```
import_content_ami.sh <s3_bucket> <s3_path>
```

- Launch the OpenShift Content AMI as an EC2 Instance from outside the snowball device
```
snowballEdge run-instances --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE> --image-id <Content_AMI_ID> --key-name <my_key_name> --instance-type sbe-c.2xlarge --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Content}]'

snowballEdge associate-address --endpoint https://<ENDPOINT> --manifest-file <MANIFEST> --unlock-code <UNLOCK CODE> --public-ip <IP to assign> --instance-id <Content_Instance_ID>
```

# Deploying OpenShift to the SBE

- Copy the SnowBall Edge Manifest to the Content Instance.

- Login to the Content Instance running on the SBE as the ec2-user

- Change directories into the openshift4-snowball directory on the content instance

```
cd /home/ec2-user/openshift4-snowball
```

## Configure Snowball Client on the Content Instance

- Run the following script to configure the snowballEdge client on the content instance
```
./configure_snowball_client.sh
```

## Configure Environemt on the Content Instance

- Run the following script to configure the environment on the content instance
```
./configure.sh
```

## Import Red Hat Core OS (RHCOS) AMI

Red Hat Core OS (RHCOS) is the base operating system of all nodes in an OpenShift cluster. The RHCOS AMI is shipped with the SBE as a disk image located in S3 on the SBE. It must be imported into the SBE as an EC2 AMI


- Run the following script to load the RHCOS disk image into the SBE on the content instance
```
import_rhcos_ami.sh
```

## Deploy Required services on the Content Instance

- Run the following script to setup the environment on the content instance. This will setup the httpd, bind, and haproxy services.
- Note that the DNS prompt refers to seting up DNS on the SBE or using an SBE external DNS
  Yes== setup DNS on the SBE, No == Use an SBE external DNS
```
./setup.sh
```

## Deploy OpenShift Cluster

- Run the following script to deploy the OpenShift cluster on the content instance
```
./deploy_openshift.sh
```

- To check that the cluster is online, use the following command
```
oc get co
```

- Once the cluster is online the bootstrap node will need to be manually terminated
