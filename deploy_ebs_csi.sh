#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "${SCRIPT_DIR}/env.sh"

# Add helm repo
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver

# Update helm repo
helm repo update

# Only needed if the IAM service is not running which it normally is
# Enable IAM service on SBE
#snowballEdge start-service ${SBE_OPTS} --service-id iam --virtual-network-interface-arns

# TODO: These are not needed yet
# Create IAM roles for EBS CSI Storage Driver

# Create IAM instance profile for above IAM role

# Attach IAM instance profile to cluster nodes

# Create secret for driver to use AWS creds
oc create secret generic aws-secret \
    --namespace kube-system \
    --from-literal "key_id=<your key>" \
    --from-literal "access_key=<your secret key>"

# Create secret with the SBE EC2 endpoint and port
oc create secret generic aws-meta \
    --namespace kube-system \
    --from-literal "endpoint=https://${SBE_ENDPOINT}:${EC2_PORT}"

# Create configmap with the SBE AWS API CA Bundle
oc create configmap awscabundle --from-file=/etc/pki/ca-trust/source/anchors/snow_cert.pem


# TODO: Something similar on SBE to attach an instance policy
#eksctl create iamserviceaccount \
#    --name ebs-csi-controller-sa \
#    --namespace kube-system \
#    --cluster my-cluster \
#    --role-name AmazonEKS_EBS_CSI_DriverRole \
#    --role-only \
#    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
#    --approve

# Install helm chart
helm upgrade --install aws-ebs-csi-driver \
    --namespace kube-system \
    -f /home/ec2-user/openshift4-snowball/config/values.yaml \
    aws-ebs-csi-driver/aws-ebs-csi-driver
