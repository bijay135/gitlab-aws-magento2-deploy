#!/bin/bash
set -euo pipefail

# Close aws vpn
echo -e "\nClosing aws vpn"
sudo pkill openvpn
echo "Aws vpn closed"
