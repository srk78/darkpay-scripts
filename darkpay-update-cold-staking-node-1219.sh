#!/bin/bash

cd /root

service darkpay stop
wget https://github.com/DarkPayCoin/darkpay-core/releases/download/v0.18.0.11/darkpay-0.18.0.11-x86_64-linux-gnu_nousb.tar.gz
tar -xzvf darkpay-0.18.0.11-x86_64-linux-gnu_nousb.tar.gz
rm /usr/local/bin/darkpayd
cp darkpay-0.18.0.11/bin/darkpayd /usr/local/bin/
service darkpay start
rm /usr/local/bin/darkpay-cli 
cp darkpay-0.18.0.11/bin/darkpay-cli /usr/local/bin/
rm -R darkpay-0.18.0.11
rm darkpay-0.18.0.11-x86_64-linux-gnu_nousb.tar.gz