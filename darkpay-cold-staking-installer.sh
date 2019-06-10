#!/bin/bash

TMP_FOLDER=$(mktemp -d)
COIN_NAME="darkpay"
COIN_CLI='darkpay-cli'
COIN_DAEMON='darkpayd'
COIN_PATH='/usr/local/bin/'
COIN_TGZ='https://github.com/DarkPayCoin/darkpay-core/releases/download/v0.18.0.7/darkpay-0.18.0.7-x86_64-linux-gnu_nousb.tar.gz'
TGZ='darkpay-0.18.0.7-x86_64-linux-gnu_nousb.tar.gz'

BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
PURPLE="\033[0;35m"
RED='\e[38;5;202m'
GREY='\e[38;5;245m'
GREEN="\033[0;32m"
NC='\033[0m'
MAG='\e[1;35m'

function display_logo() {

echo -e "                                                                                                                                                     
       \e[38;5;52m      .::::::::::::::::::::::::::::::::::..                                        
       \e[38;5;202m   ..::::c:cc:c:c:c:c:c:c:c:c:c:c:c:cc:c::::.                                      
          .:.                                    ::.                                      
          .:c:                                   c::                                       
           .:c:                                 c::                                       
            .:c:                               cc:                                        
             .:c:                             c::                                         
              .:c:                           c::                                         
               .:c:                         c::                                            
                .:cc                       c::                                            
                 .:cc                     c::                                              
                  .:cc                   c::                                               
                   .:cc                 c::                                                
                    .:cc               c::                                                 
                     .:cc             c::                                                  
                      .::c           c:.                                                   
                       .:cc         c::                                                    
                        .::c       c:.                                                     
                         .::c     c:.                                                      
                           ::c.  c:.                                                       
                             .:.:.            \e[0m                                               
 
888888ba                    dP       \e[38;5;202m 888888ba                    \e[0m
88     8b                   88       \e[38;5;202m 88     8b                   \e[0m
88     88 .d8888b. 88d888b. 88  .dP  \e[38;5;202ma88aaaa8P' .d8888b. dP    dP \e[0m
88     88 88'   88 88'   88 88888     \e[38;5;202m88        88    88 88    88 \e[0m
88    .8P 88.  .88 88       88   8b.  \e[38;5;202m88        88.  .88 88.  .88 \e[0m
8888888P   88888P8 dP       dP    YP  \e[38;5;202mdP         88888P8  8888P88 \e[0m
                                                  \e[38;5;202m             88\e[0m
                                                  \e[38;5;202m        d8888P  \e[0m
"
sleep 0.5
}

function start_installation() {
echo -e "
▼ DarkPay Cold Staking Node Installer 
---------------------------------------------------------------------
"

echo -e "${GREY}Welcome to DarkPay Cold Staking Node installer${NC}"

}

function download_node() {
  echo -e "${GREY}Downloading and Installing DarkPay Daemon...${NC}"
  cd $TMP_FOLDER >/dev/null 2>&1
  wget -q $COIN_TGZ
  tar -zxvf $TGZ >/dev/null 2>&1
  cd darkpay-0.18.0.7/bin/
  chmod +x $COIN_DAEMON
  chmod +x $COIN_CLI
  mv $COIN_DAEMON $COIN_PATH
  mv $COIN_CLI $COIN_PATH
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}

function configure_systemd() {

echo -e "${GREY}Installing DarkPay Service...${NC}"

EXSTART="ExecStart=$COIN_PATH$COIN_DAEMON -daemon"

  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target
[Service]
User=root
Group=root
Type=forking
$EXSTART
ExecStop=-$COIN_PATH$COIN_CLI stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function create_wallet() {
	echo -e "${GREY}Creating DarkPay Wallet${NC}"
	WALLET=$($COIN_PATH$COIN_CLI getnewextaddress 'stakingnode')
	clear
}

function import_seed() {
	echo -e "${GREY}Importing seed...${NC}"
	MNEMONIC=$($COIN_PATH$COIN_CLI mnemonic new | grep mnemonic | cut -f2 -d":" | sed 's/\ "//g' | sed 's/\",//g')
	$COIN_PATH$COIN_CLI extkeyimportmaster "$MNEMONIC"
}

function setup_receiving_address() {
echo -e "${GREY}Setting up receiving address...${NC}"

}

function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"
  ufw allow 16667/tcp comment "DarkPay Daemon port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  clear
}

function important_information() {
	echo
	echo -e "${BLUE}================================================================================================================================${NC}"
	echo -e "${BLUE}================================================================================================================================${NC}"
	echo -e "DarkPay Cold Staking Node is up and running.${NC}."
	echo -e "Below you'll find the information you need to remember.${NC}."
	echo -e "Wallet Seed: ${RED}$MNEMONIC${NC}."
	echo -e "Wallet public key: ${GREEN}$WALLET${NC}"
	echo 
}


display_logo
start_installation
download_node
configure_systemd
sleep 10
import_seed
create_wallet
enable_firewall
important_information