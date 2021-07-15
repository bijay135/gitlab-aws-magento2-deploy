#!/bin/bash
set -euo pipefail

# Variables
APPLICATION_STATE=$(cat $scripts_root/application-state)

echo "Running golden deploy script"
cd $mage_root

# Sync fresh artifacts, generated, static and view_preprocessed from build
if [ $APPLICATION_STATE == 1 ] ; then
	echo -e "\nApplication state changes found, starting golden deployment"
	echo "Syncing fresh artifacts from build to current"
	sudo rsync -a --exclude-from=".rsyncignore" $build_root/ . --delete
	sudo rsync -a $build_root/app/etc/config.php.mod app/etc/config.php
	echo "Fresh artifacts sync complete"
	echo "Clearing current generated"
	until rm -rf generated/* ; do
	    echo "Could not clear generated, trying again"
	done
	echo "Clearing current static and view_preprocessed"
	find pub/static/* var/view_preprocessed/* -maxdepth 0 ! -name "_cache" -exec rm -rf {} \+
	echo "Syncing fresh generated from build to current"
	sudo rsync -a $build_root/generated/* generated/
	echo "Fresh generated sync complete"
	echo "Syncing fresh static and view_preprocessed from build to current"
	sudo rsync -aR $build_root/./pub/static/* $build_root/./symlinks/view_preprocessed/* .
	echo "Fresh static and view_preprocessed sync complete"
	echo "Golden deployment complete"
else
	echo -e "\nNo application state changes found, skipping golden deployment"
fi

echo -e "\nGolen deploy script complete"
