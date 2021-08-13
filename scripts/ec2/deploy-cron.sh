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

# Sync fresh artifacts, generated, static and view_preprocessed from build
if [ $APPLICATION_STATE == 1 ] ; then
	echo -e "\nApplication state changes found, starting cron deployment"
	echo "Syncing fresh artifacts from build to current"
	sudo rsync -a --exclude-from=".rsyncignore" $GOLDEN_HOST:\$build_root/ . --delete
	echo "Fresh artifacts sync complete"
	echo "Clearing current generated"
	until rm -rf generated/* ; do
	    echo "Could not clear generated, trying again"
	done
	echo "Clearing current static and view_preprocessed"
    find pub/static/* var/view_preprocessed/* -maxdepth 0 ! -name "_cache" -exec rm -rf {} \+
	echo "Syncing fresh generated from build to current"
	sudo rsync -a $GOLDEN_HOST:\$build_root/generated/* generated/
	echo "Fresh generated sync complete"
	echo "Syncing fresh static and view_preprocessed from build to current"
	sudo rsync -aR $GOLDEN_HOST:\$build_root/./pub/static/* $GOLDEN_HOST:\$build_root/./symlinks/view_preprocessed/* .
	echo "Fresh static and view_preprocessed sync complete"
	echo "Cron deployment complete"
else
	echo -e "\nNo application state changes found, skipping cron deployment"
fi

echo -e "\nCron deploy script complete"
