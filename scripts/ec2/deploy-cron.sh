#!/bin/bash
set -euo pipefail

# Variables
BRANCH_NAME=$1
if [ $BRANCH_NAME == "production" ] ; then
    GOLDEN_HOST="production_golden"
elif [ $BRANCH_NAME == "staging" ] ; then
    GOLDEN_HOST="staging_golden"
fi
sudo ssh $GOLDEN_HOST "cat \$scripts_root/application-state" > $scripts_root/application-state
APPLICATION_STATE=$(cat $scripts_root/application-state)

echo "Running cron deploy script"
cd $mage_root

# Sync fresh artifacts and generated from build
if [ $APPLICATION_STATE == 1 ] ; then
	echo -e "\nApplication state changes found, starting cron deployment"
	echo "Syncing fresh artifacts from build to current"
	sudo rsync -a --exclude-from=".rsyncignore" $GOLDEN_HOST:\$build_root/ . --delete
	echo "Fresh artifacts sync complete"
	echo "Clearing current generated"
	until rm -rf generated/* ; do
	    echo "Could not clear generated, trying again"
	done
	echo "Syncing fresh generated from build to current"
	sudo rsync -a $GOLDEN_HOST:\$build_root/generated/* generated/
	echo "Fresh generated sync complete"
	echo "Cron deployment complete"
else
	echo -e "\nNo application state changes found, skipping cron deployment"
fi

echo -e "\nCron deploy script complete"
