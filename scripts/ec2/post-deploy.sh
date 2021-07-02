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

# Upgrade database
if [ $APPLICATION_STATE == 1 ] ; then
    echo -e "\nApplication state changes found, upgrading database"
    bin/magento setup:upgrade --keep-generated -n
else
	echo -e "\nNo Application state changes found, skipping database upgrade"
fi

# Wait for instance refresh to fully finish, clear static cache and flush caches
echo -e "\nWaiting for instance refresh to finish .."
while [ $(instanceRefreshStatus) != 1 ] ; do
    sleep 15
done
echo "Clearing static cache"
rm -rf pub/static/_cache/*
echo "Instance refresh finished successfully"
echo "Flushing caches"
bin/magento cache:flush -q
echo "Caches flushed"

echo -e "\nPost deploy script complete"
