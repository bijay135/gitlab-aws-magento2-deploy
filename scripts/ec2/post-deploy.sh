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
CACHE_STATE=$(cat $scripts_root/cache-state)

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

# Wait for instance refresh to fully finish
echo -e "\nWaiting for instance refresh to finish .."
while [ $(instanceRefreshStatus) != 1 ] ; do
    sleep 15
done
echo "Instance refresh finished successfully"

# Refresh caches
if [ $APPLICATION_STATE == 1 ] ; then
    echo -e "\nApplication state changes found, refreshing caches"
    echo "Clearing static cache"
    rm -rf pub/static/_cache/*
    echo "Flushing legacy cache databases and setting alternate to active"
    if [ $CACHE_STATE == a ] ; then
        while redis-cli -h $aws_redis info keyspace | grep -q "db1" ; do
            redis-cli -h $aws_redis -n 1 flushdb > /dev/null
        done
        redis-cli -h $aws_redis -n 2 flushdb > /dev/null
        echo "b" > $scripts_root/cache-state
    elif [ $CACHE_STATE == b ]; then
        while redis-cli -h $aws_redis info keyspace | grep -q "db3" ; do
             redis-cli -h $aws_redis -n 3 flushdb > /dev/null
        done
        redis-cli -h $aws_redis -n 4 flushdb > /dev/null
        echo "a" > $scripts_root/cache-state
    fi
    echo "Legacy cache databases flushed and alternate set to active"
    echo "Caches refresh complete"
else
    echo -e "\nNo Application state changes found, skipping caches refresh"
fi


echo -e "\nPost deploy script complete"
