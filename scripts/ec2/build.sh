#!/bin/bash
set -euo pipefail

# Variables
BRANCH_NAME=$1
FORCE_ZERO_DOWNTIME=$2

echo "Running build script"
cd $build_root

# Fetch changes
echo -e "\nFetching changes"
git fetch origin $BRANCH_NAME
set +eo pipefail
git diff --exit-code --quiet origin/$BRANCH_NAME -- .ec2/shared/nginx .ec2/$BRANCH_NAME/nginx ; NGINX=$?
git diff --exit-code --quiet origin/$BRANCH_NAME -- .ec2/shared/php ; PHP=$?
git diff --exit-code --quiet origin/$BRANCH_NAME -- .ec2/shared/logrotate .ec2/$BRANCH_NAME/logrotate ; LOGROTATE=$?
git diff --exit-code --quiet origin/$BRANCH_NAME -- .ec2/$BRANCH_NAME/magento ; MAGENTO=$?
git diff --exit-code --quiet origin/$BRANCH_NAME -- composer.json ; COMPOSER=$?
git diff --exit-code --quiet origin/$BRANCH_NAME -- m2-patches ; PATCHES=$?
git diff --exit-code --quiet origin/$BRANCH_NAME -- app/code app/design app/etc/config.php ; APP=$?
set -eo pipefail
if [ $FORCE_ZERO_DOWNTIME == 1 ] ; then
    APPLICATION_STATE=0
    echo "0" > $scripts_root/application-state
elif [ $COMPOSER == 1 ] || [ $PATCHES == 1 ] || [ $APP == 1 ] ; then
    APPLICATION_STATE=1
    echo "1" > $scripts_root/application-state
else
    APPLICATION_STATE=0
    echo "0" > $scripts_root/application-state
fi

# Prepare deploy summary
echo -e "\n###################### Deployment Summary ######################"
echo "####################### Server Section #########################"
echo -e "# \t\t\t nginx     => $NGINX \t\t\t #"
echo -e "# \t\t\t php       => $PHP \t\t\t #"
echo -e "# \t\t\t logrotate => $LOGROTATE \t\t\t #"
echo -e "# \t\t\t magento   => $MAGENTO \t\t\t #"
echo "##################### Application Section ######################"
echo -e "# \t\t\t Composer  => $COMPOSER \t\t\t #"
echo -e "# \t\t\t Patches   => $PATCHES \t\t\t #"
echo -e "# \t\t\t App       => $APP \t\t\t #"
echo "################################################################"

# Pull latest changes
echo -e "\nPulling latest changes"
git reset --hard origin/$BRANCH_NAME

# Build server changes
if [ $NGINX == 1 ] || [ $PHP == 1 ] || [ $LOGROTATE == 1 ] || [ $MAGENTO == 1 ] ; then
    echo -e "\nServer state changes found, starting server build"
    if [ $NGINX == 1 ] ; then
    	echo "Nginx changes found, updating"
        sudo cp -f .ec2/shared/nginx/nginx.conf /etc/nginx/
        sudo cp -f .ec2/shared/nginx/magento.sample /etc/nginx/conf.d/
    	sudo cp -f .ec2/$BRANCH_NAME/nginx/* /etc/nginx/conf.d/
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
    	sudo cp -f .ec2/$BRANCH_NAME/logrotate/* /etc/logrotate.d/
    	echo "Logrotate update complete"
    fi
    if [ $MAGENTO == 1 ] ; then
        echo "Magento changes found, updating"
    	cp -f .ec2/$BRANCH_NAME/magento/* $mage_root/app/etc/
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
else
    echo -e "\nNo composer changes found, skipping"
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
if [ $APPLICATION_STATE == 1 ] || [ $FORCE_ZERO_DOWNTIME == 1 ] ; then
    echo -e "\nApplication state changes found, starting application build"
    if [ $FORCE_ZERO_DOWNTIME == 1 ] ; then
        echo "Clearing build generated"
        rm -rf generated/*
    else
        echo "Clearing build generated, static and view_preprocessed"
        rm -rf generated/* && rm -rf pub/static/* && rm -rf var/view_preprocessed/*
    fi
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
    rm -f app/etc/config.php.bk
    echo "Modules reconcilation complete"
    echo "Compiling code"
    bin/magento setup:di:compile -q
    echo "Code Compliation complete"
    if [ $FORCE_ZERO_DOWNTIME != 1 ] ; then
        echo "Deploying static content"
        bin/magento setup:static-content:deploy -f -j 4 -q
        echo "Static content deployment complete"
    fi
    echo "Application build complete"
else
    echo -e "\nNo application state changes found, skipping app build"
fi

echo -e "\nBuild script complete"
