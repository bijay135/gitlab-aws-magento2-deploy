#!/bin/bash
set -euo pipefail

# Variables
INSTANCE_BRANCH_NAME=$1
if [ $INSTANCE_BRANCH_NAME == "production" ] ; then
    source $scripts_root/.env.prod
elif [ $INSTANCE_BRANCH_NAME == "staging" ] ; then
    source $scripts_root/.env.stag
fi

echo "Running warm up script"

# Warm up most used pages
echo -e "\nWarming up pages"
curl -s "$BASE_URL"  > /dev/null
curl -s "$BASE_URL/htbwbkgcyymmzzon"  > /dev/null
curl -s "$BASE_URL/checkout/cart/"  > /dev/null
echo "Pages warm up complete"

echo -e "\nWarm up script complete"
