#!/bin/bash
set -euo pipefail

# Variables
DEPLOY_BRANCH_NAME="deploy"
INSTANCE_BRANCH_NAME=$1
FORCE_APPLICATION_BUILD=$2
CURRENT_DATE=$(date +%s)
THIRTY_DAYS_AGO_DATE=$(date -d 'now - 30 days' +%s)
if ! COMPOSER_UPDATED=$(cat $scripts_root/composer-updated 2> /dev/null) ; then
    echo $CURRENT_DATE > $scripts_root/composer-updated
    COMPOSER_UPDATED=$(cat $scripts_root/composer-updated)
fi

echo "Running build script"
cd $build_root

# Fetch changes and prepare deploy summary
echo -e "\nFetching changes and preparing deploy summary"
git fetch origin $INSTANCE_BRANCH_NAME -q
git checkout $DEPLOY_BRANCH_NAME -q && git reset --hard origin/$INSTANCE_BRANCH_NAME -q
set +eo pipefail
git diff --exit-code --quiet $INSTANCE_BRANCH_NAME -- .ec2/shared/nginx .ec2/$INSTANCE_BRANCH_NAME/nginx ; NGINX=$?
git diff --exit-code --quiet $INSTANCE_BRANCH_NAME -- .ec2/shared/php ; PHP=$?
git diff --exit-code --quiet $INSTANCE_BRANCH_NAME -- .ec2/shared/logrotate .ec2/$INSTANCE_BRANCH_NAME/logrotate ; LOGROTATE=$?
git diff --exit-code --quiet $INSTANCE_BRANCH_NAME -- .ec2/$INSTANCE_BRANCH_NAME/magento ; MAGENTO=$?
git diff --exit-code --quiet $INSTANCE_BRANCH_NAME -- composer.json ; COMPOSER=$?
git diff --exit-code --quiet $INSTANCE_BRANCH_NAME -- m2-patches ; PATCHES=$?
git diff --exit-code --quiet $INSTANCE_BRANCH_NAME -- app/code app/design app/etc/config.php ; APP=$?
set -eo pipefail
if [ $COMPOSER == 1 ] || [ $PATCHES == 1 ] || [ $APP == 1 ] || [ $FORCE_APPLICATION_BUILD == 1 ] ; then
    APPLICATION_STATE=1
    echo "1" > $scripts_root/application-state
else
    APPLICATION_STATE=0
    echo "0" > $scripts_root/application-state
fi
echo -e "\n########################### Deployment Summary ##########################"
echo "|-------------------------- Pipeline Section ---------------------------|"
echo -e "| \t\t Force Application Build \t => \t $FORCE_APPLICATION_BUILD \t\t |"
echo "|--------------------------- Server Section ----------------------------|"
echo -e "| \t\t Nginx     \t\t\t => \t $NGINX \t\t |"
echo -e "| \t\t Php       \t\t\t => \t $PHP \t\t |"
echo -e "| \t\t Logrotate \t\t\t => \t $LOGROTATE \t\t |"
echo -e "| \t\t Magento   \t\t\t => \t $MAGENTO \t\t |"
echo "|------------------------- Application Section -------------------------|"
echo -e "| \t\t Composer  \t\t\t => \t $COMPOSER \t\t |"
echo -e "| \t\t Patches   \t\t\t => \t $PATCHES \t\t |"
echo -e "| \t\t App       \t\t\t => \t $APP \t\t |"
echo "#########################################################################"

# Build server changes
if [ $NGINX == 1 ] || [ $PHP == 1 ] || [ $LOGROTATE == 1 ] || [ $MAGENTO == 1 ] ; then
    echo -e "\nServer state changes found, starting server build"
    if [ $NGINX == 1 ] ; then
    	echo "Nginx changes found, updating"
        sudo cp -f .ec2/shared/nginx/nginx.conf /etc/nginx/
        sudo cp -f .ec2/shared/nginx/magento.sample /etc/nginx/conf.d/
        sudo cp -f .ec2/$INSTANCE_BRANCH_NAME/nginx/* /etc/nginx/conf.d/
    	sudo nginx -t
    	sudo systemctl restart nginx
    	echo "Nginx update complete"
    fi
    if [ $PHP == 1 ] ; then
        echo "Php changes found, updating"
        sudo cp -f .ec2/shared/php/www2.conf /etc/php/7.4/fpm/pool.d/
    	sudo cp -f .ec2/shared/php/php-fpm.ini /etc/php/7.4/fpm/conf.d/
    	sudo cp -f .ec2/shared/php/php-cli.ini /etc/php/7.4/cli/conf.d/
    	sudo systemctl restart php7*
    	echo "Php update complete"
    fi
    if [ $LOGROTATE == 1 ] ; then
        echo "Logrotate changes found, updating"
    	sudo cp -f .ec2/shared/logrotate/* /etc/logrotate.d/
        sudo cp -f .ec2/$INSTANCE_BRANCH_NAME/logrotate/* /etc/logrotate.d/
    	echo "Logrotate update complete"
    fi
    if [ $MAGENTO == 1 ] ; then
        echo "Magento changes found, updating"
        cp -f .ec2/$INSTANCE_BRANCH_NAME/magento/* $mage_root/app/etc/
        $mage_root/bin/magento app:config:import -q
        echo "Magento update complete"
    fi
    echo "Server build complete"
else
    echo -e "\nNo server state changes found, skipping"
fi

# Build composer changes
if [ $COMPOSER == 1 ] ; then
    echo -e "\nComposer changes found, updating new packages"
    composer update -n
    echo $CURRENT_DATE > $scripts_root/composer-updated
elif (( $THIRTY_DAYS_AGO_DATE >= $COMPOSER_UPDATED )) ; then
    echo -e "\nComposer not updated in last 30 days, updating new packages"
    COMPOSER=1
    composer update -n
    echo $CURRENT_DATE > $scripts_root/composer-updated
else
    echo -e "\nNo composer changes found and composer updated in last 30 days, skipping"
fi

# Build patches
if [ $COMPOSER == 1 ] || [ $PATCHES == 1 ]  ; then
    echo -e "\nPatches state changes found, starting patch build"
    if find m2-patches -maxdepth 0 > /dev/null 2>&1 || find $mage_root/m2-patches -maxdepth 0 > /dev/null 2>&1 ; then
        if ! find m2-patches $mage_root/m2-patches -maxdepth 0 > /dev/null 2>&1 ; then
            echo "Required directory not found for comparison, creating"
            mkdir -p m2-patches && mkdir -p $mage_root/m2-patches
            echo "Created requred directory for comparision"
        fi
        set +eo pipefail
        PATCHES_DIFF=$(diff -q m2-patches $mage_root/m2-patches)
        set -eo pipefail
        if grep "/m2-patches" <<< $PATCHES_DIFF > /dev/null 2>&1 ; then
            echo "Some patches were removed, reverting"
            for file in $(diff -q m2-patches $mage_root/m2-patches | grep "/m2-patches" | cut -f 2 -d ":" | cut -f 2 -d " "); do
                if git apply -R "$mage_root/m2-patches/$file" --check > /dev/null 2>&1 ; then
                    echo "Reverting $file" ;
                    git apply -R "$mage_root/m2-patches/$file"
                else
                    echo "$file could not be reverted, remove the patched module and run 'composer install' manually"
                fi
            done
        fi
    fi
    if find m2-patches/* -maxdepth 0  > /dev/null 2>&1 ; then
        echo "Patches found, applying"
        for file in m2-patches/* ; do
            if ! git apply -R $file --check > /dev/null 2>&1 ; then
                echo "Applying ${file##*/}"
                git apply $file;
            else
                echo "${file##*/} already applied"
            fi
        done
    else
        echo "No patches found, skipping"
        rm -rf m2-patches
    fi
    echo "Patches build complete"
else
    echo -e "\nNo patches state changes found, skipping"
fi

# Build application changes
if [ $APPLICATION_STATE == 1 ] ; then
    echo -e "\nApplication state changes found, starting application build"
    echo "Clearing build generated, static and view_preprocessed"
    rm -rf generated/* && rm -rf pub/static/* && rm -rf var/view_preprocessed/*
    echo "Reconciling modules with shared config"
    if ! ls -l app/etc/ | grep -q "config.php.bk" ; then
        cp -af app/etc/config.php app/etc/config.php.bk
    fi
    echo "Enabling all new modules"
    bin/magento module:enable --all -q
    set +eo pipefail
    DISABLED_MODULES=$(diff app/etc/config.php app/etc/config.php.bk | grep "=> 0" | cut -d "'" -f2)
    set -eo pipefail
    if [ -n "$DISABLED_MODULES" ] ; then
        echo "Updating disabled modules"
        bin/magento module:disable -q $DISABLED_MODULES
    fi
    cp -af app/etc/config.php app/etc/config.php.mod
    echo "Modules reconcilation complete"
    echo "Compiling code"
    bin/magento setup:di:compile -q
    echo "Code Compliation complete"
    echo "Deploying static content"
    bin/magento setup:static-content:deploy -f -j 4 -q
    echo "Static content deployment complete"
    cp -af app/etc/config.php.bk app/etc/config.php && rm -f app/etc/config.php.bk
    echo "Application build complete"
else
    echo -e "\nNo application state changes found, skipping application build"
fi

# Reset instance to changes
echo -e "\nResetting instance to latest changes"
git checkout $INSTANCE_BRANCH_NAME -q && git reset --hard $DEPLOY_BRANCH_NAME

echo -e "\nBuild script complete"
