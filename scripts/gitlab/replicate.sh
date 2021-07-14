#!/bin/bash
set -euo pipefail

# Variables
BRANCH_NAME=$1
if [ $BRANCH_NAME == "production" ] ; then
    source $scripts_root/.env.prod
elif [ $BRANCH_NAME == "staging" ] ; then
    source $scripts_root/.env.stag
fi

echo "Running replication script"

echo -e "\nWaiting 60 seconds for ec2 instance to be stable .."
sleep 60
echo "Selected auto scaling group is $ASG_NAME"

# Create new image
echo -e "\nCreating new image"
IMAGE_ID=$(aws ec2 create-image --instance-id $INSTANCE_ID --name $NEW_IMAGE_NAME --no-reboot --output text)
echo "Created new image $IMAGE_ID of instance $INSTANCE_ID"

# Create new launch configuration and update auto scaling group to use it
echo -e "\nCreating new launch configuration"
aws autoscaling create-launch-configuration --launch-configuration-name $NEW_LC_NAME --image-id $IMAGE_ID \
    --instance-type $INSTANCE_TYPE --key $KEY_FILE --security-groups $SECURITY_GROUP_ID \
    --user-data file://$scripts_root/lc-userdata --iam-instance-profile $IAM_INSTANCE_PROFILE
echo "Created new launch configuration $NEW_LC_NAME"
echo "Updating auto scaling group to use new launch configuration"
aws autoscaling update-auto-scaling-group --auto-scaling-group-name $ASG_NAME --launch-configuration-name $NEW_LC_NAME
echo "Updated $ASG_NAME to use $NEW_LC_NAME"
echo "Waiting for new image to be available .."
aws ec2 wait image-available --image-ids $IMAGE_ID
echo "The image $IMAGE_ID is now available and another deployment is set for execution"

# Start instance refresh
echo -e "Starting instance refresh"
aws autoscaling start-instance-refresh --auto-scaling-group-name $ASG_NAME \
    --preferences '{"MinHealthyPercentage": 10, "InstanceWarmup": 30}'

echo -e "\nReplication script complete"
