#!/bin/bash
set -euo pipefail

# Variables
BRANCH_NAME=$1
if [ $BRANCH_NAME == "production" ] ; then
    source $scripts_root/.env.prod
elif [ $BRANCH_NAME == "staging" ] ; then
    source $scripts_root/.env.stag
fi
APPLICATION_STATE=$(cat $scripts_root/application-state)

# Functions
instanceRefreshStatus(){
    REFRESH_STATUS=$(aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME \
            --query InstanceRefreshes[0].{PercentageComplete:PercentageComplete})
    if echo $REFRESH_STATUS | grep -q "100" ; then
        echo "1"
    else
        echo "0"
    fi
}

echo "Running post deploy script"
cd $mage_root

# Upgrade database and flush caches
if [ $APPLICATION_STATE == 1 ] ; then
    echo -e "\nApplication state changes found, upgrading database"
    bin/magento setup:upgrade --keep-generated -n
    echo "Flushing caches"
    bin/magento cache:flush -q
    echo "Caches flushed"
else
	echo -e "\nNo Application state changes found, skipping database upgrade"
fi

# Wait for instance refresh to fully finish
echo -e "\nWaiting for instance refresh to finish .."
while [ $(instanceRefreshStatus) != 1 ] ; do
    sleep 15
done
echo "Instance refresh finished successfully"

# Disable maintenane mode and revert health check configuration to original
if bin/magento maintenance:status | grep -q "is active" ; then
    echo -e "\nDisabling maintenance mode"
    bin/magento maintenance:disable
    echo "Reverting unhealthy threshold and health check interval"
    REVERT_HEALTH_CHECK=$(aws elbv2 modify-target-group --target-group-arn $TARGET_GROUP_ARN --unhealthy-threshold-count \
        $ORIGINAL_UNHEALTHY_THRESHOLD --health-check-interval-seconds $ORIGINAL_HEALTH_CHECK_INTERVAL \
        --query 'TargetGroups[0].TargetGroupName')
    echo "Reverted health check configuration for $REVERT_HEALTH_CHECK"
else
    echo -e "\nMaintenance mode is not active, skipping"
fi

echo -e "\nPost deploy script complete"
