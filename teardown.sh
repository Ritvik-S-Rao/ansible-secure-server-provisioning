#!/bin/bash


#################################################################
# Author : Ritvik S Rao
# Date : 12-Aug-2026
#
#
# Version : v1
# Description : This is a clean-up script used to delete ec2 instance, key pairs, security groups after executing the rate-limit.sh script
# Dependencies : AWS-CLI
##################################################################


# Load the infrastructure state
if [ -f .state.env ]; then
    source .state.env
    echo "State file loaded successfully."
else
    echo "Error: .state.env not found. Are you sure the infrastructure is deployed?"
    exit 1
fi


# Terminate the ec2 instance
echo "Terminating EC2 instance $INSTANCE_ID in region $REGION"
aws ec2 terminate-instances \
    --region $REGION \
    --instance-ids $INSTANCE_ID > /dev/null

echo "Waiting for instance to fully terminate..."
aws ec2 wait instance-terminated \
    --region $REGION \
    --instance-ids $INSTANCE_ID
echo "Instance terminated successfully."
echo ""


# Delete Security group
# Note : Security Group cannot be deleted while the instance is not terminated that's why we wait for it to terminate
echo "Deleting Security Group ($SG_ID)..."
aws ec2 delete-security-group \
    --region $REGION \
    --group-id $SG_ID
echo "Security Group deleted."
echo ""

# 3. Delete the Key Pair from AWS
echo "Deleting AWS Key Pair ($KEY_NAME)..."
aws ec2 delete-key-pair \
    --region $REGION \
    --key-name $KEY_NAME
echo "Key Pair deleted from AWS."
echo ""


# 4. Clean up local files
echo "Cleaning up local key file and state file..."
rm -f $KEY_PATH
rm -f .state.env
echo "Local files removed."
echo ""

echo "Teardown complete! All resources have been successfully destroyed."
