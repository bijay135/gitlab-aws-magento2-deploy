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

echo "Running asg deploy script"
cd $mage_root

# Enable maintenance mode and modify health check configuration temporarily
if [ $APPLICATION_STATE == 1 ] ; then
    echo -e "\nApplication state changes found, enabling maintenance mode"
    bin/magento maintenance:enable
    echo "Increasing unhealthy threshold and health check interval"
    MODIFY_HEALTH_CHECK=$(aws elbv2 modify-target-group --target-group-arn $TARGET_GROUP_ARN --unhealthy-threshold-count \
        $TEMP_UNHEALTHY_THRESHOLD --health-check-interval-seconds $TEMP_HEALTH_CHECK_INTERVAL \
        --query 'TargetGroups[0].TargetGroupName')
    echo "Inceased health check configuration for $MODIFY_HEALTH_CHECK"
else
    echo -e "\nNo application state changes found, maintenance mode not required"
fi

# Sync fresh static and view_preprocessed from build
if [ $APPLICATION_STATE == 1 ] ; then
    echo -e "\nApplication state changes found, starting asg deployment"
    echo "Clearing current static and view_preprocessed"
    until find pub/static/*/*/* var/view_preprocessed/*/*/* -maxdepth 0 | parallel -j 0 rm -rf {} ; do
        echo "Could not clear static or view_preprocessed, trying again"
    done
    rm -rf pub/static/* && rm -rf var/view_preprocessed/*
    echo "Syncing fresh static and view_preprocessed from build to current"
    find $build_root/./pub/static/*/*/* $build_root/./var/view_preprocessed/*/*/* -maxdepth 0 | parallel -j 0 sudo rsync -aR {} .
    cp -af $build_root/pub/static/deployed_version.txt pub/static/
    echo "Fresh static and view_preprocessed sync complete"
    echo "Asg deployment complete"
else
    echo -e "\nNo application state changes found, skipping asg deployment"
fi

echo -e "\nAsg deploy script complete"
