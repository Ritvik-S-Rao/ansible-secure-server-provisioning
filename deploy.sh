#!/bin/bash


#################################################################
# Author : Ritvik S Rao
# Date : 12-Aug-2026
#
#
# Version : v1
# Description : This script is used to create and configure ec2 instance, key pairs, security groups to further execute the rate-limit.sh script
# Dependencies : AWS-CLI
##################################################################


# Configure Variables and static information that is required to create instances
REGION="ap-south-1"
TIMESTAMP=$(date +%s)
AMI_ID=$(aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id --region $REGION --query "Parameters[0].Value" --output text)
KEY_NAME="rate-limit-dashboard-$TIMESTAMP"
KEY_PATH="./${KEY_NAME}.pem"
SG_NAME="dashboard-sg-$TIMESTAMP"


echo "Generating Key-Pair for SSH..."
# Creating a key-pair
aws ec2 create-key-pair \
	--region $REGION \
	--key-name $KEY_NAME \
	--query 'KeyMaterial' \
	--output text > $KEY_PATH

# Modifying Permissions for SSH
chmod 400 $KEY_PATH
echo "Key saved securely to $KEY_PATH"
echo ""
echo ""

# Creating Security Group
echo "Creating Security Group: $SG_NAME..."
SG_ID=$(aws ec2 create-security-group \
    --region $REGION \
    --group-name $SG_NAME \
    --description "Allows SSH and HTTP traffic for the rate limit dashboard" \
    --query 'GroupId' \
    --output text)


# Fetch your current public IP address silently using AWS's checkip service
MY_IP=$(curl -s checkip.amazonaws.com)


# Configuring Security group to open port 22 for ssh access (Restricted explicitly to your IP address)
aws ec2 authorize-security-group-ingress \
    --region $REGION \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr ${MY_IP}/32 > /dev/null


# Configuring Security group to open Port 80 for HTTP access (Open to the world so anyone can view the dashboard)
aws ec2 authorize-security-group-ingress \
    --region $REGION \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 > /dev/null
echo "Security Group created and ports configured."
echo ""
echo ""

# Creating and launching ec2 instance
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --region $REGION \
    --image-id $AMI_ID \
    --instance-type t3.micro \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --query 'Instances[0].InstanceId' \
    --output text)
echo "Waiting 30 seconds for instance $INSTANCE_ID to receive a Public IP..."
sleep 30
echo ""
echo ""

# Extracting Public IP Address of the VM
PUBLIC_IP=$(aws ec2 describe-instances \
    --region $REGION \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
echo "Server is booting at IP: $PUBLIC_IP"
sleep 90
echo ""
echo ""


# Ansible Handoff Bridge to configure the VM
mkdir -p inventories/dev
echo "[webservers]" > inventories/dev/hosts.ini
echo "$PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file=$KEY_PATH" >> inventories/dev/hosts.ini

echo "Triggering Ansible Playbook for Configuration..."
# Bypass StrictHostKeyChecking for the first SSH connection so it doesn't freeze asking for 'yes/no'
export ANSIBLE_HOST_KEY_CHECKING=False 
ansible-playbook -i inventories/dev/hosts.ini playbook.yml --ask-vault-pass


#Output
echo "Deployment complete! Your dashboard is live."
echo "Visit: http://$PUBLIC_IP"


# Save state for teardown
echo "Exporting infrastructure state for future teardown..."
echo "INSTANCE_ID=$INSTANCE_ID" > .state.env
echo "SG_ID=$SG_ID" >> .state.env
echo "KEY_NAME=$KEY_NAME" >> .state.env
echo "KEY_PATH=$KEY_PATH" >> .state.env
echo "REGION=$REGION" >> .state.env
