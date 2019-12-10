#!/bin/bash

echo -e "Preparing the VPS for auto update setup"
apt-get update >/dev/null 2>&1

apt install -y curl >/dev/null 2>&1
apt install -y jq >/dev/null 2>&1

cd /root
wget https://raw.githubusercontent.com/Skelt0r/darkpay-scripts/master/darkpay-auto-updater.sh
chmod +x darkpay-auto-updater.sh

line="1 0 * * * /root/darkpay-auto-updater.sh"
username=$(whoami)
(crontab -u $username -l; echo "$line" ) | crontab -u $username -