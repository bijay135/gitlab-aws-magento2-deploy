#!/bin/bash
set -euo pipefail

# Connect aws vpn
if ifconfig | grep -q "tun0" ; then
    echo -e "Aws vpn already connected\n"
else
    echo "Connecting aws vpn .."
    sudo openvpn $cloud_aws --daemon
    while ! ifconfig | grep -q "tun0" ; do
        sleep 1
    done
    echo -e "Aws vpn connected\n"
fi
