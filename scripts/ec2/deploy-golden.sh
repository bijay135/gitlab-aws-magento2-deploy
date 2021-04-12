#!/bin/bash
set -euo pipefail

# Variables
APPLICATION_STATE=$(cat $scripts_root/application-state)

echo "Running golden deploy script"
cd $mage_root

# Sync fresh artifacts and generated from build
if [ $APPLICATION_STATE == 1 ] ; then
	echo -e "\nApplication state changes found, starting golden deployment"
	echo "Syncing fresh artifacts from build to current"
	sudo rsync -a --exclude-from=".rsyncignore" $build_root/ . --delete
	cp -af $build_root/app/etc/config.php app/etc/
	echo "Fresh artifacts sync complete"
	echo "Clearing current generated"
	until rm -rf generated/* ; do
	    echo "Could not clear generated, trying again"
	done
	echo "Syncing fresh generated from build to current"
	sudo rsync -a $build_root/generated/* generated/
	echo "Fresh generated sync complete"
	echo "Golden deployment complete"
else
	echo -e "\nNo application state changes found, skipping golden deployment"
fi

echo -e "\nGolen deploy script complete"
