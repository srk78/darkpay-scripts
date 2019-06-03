#!/bin/bash

# Script installs DarkPay cold staking daemon
# Cloned from https://github.com/dasource/partyman 
# Edited to function solely for installing cold staking node
# Copyright (c) 2015-2017 moocowmoo
# Copyright (c) 2017 dasource
# Copyright (c) 2019 Skelt0r

# variables are for putting things in ----------------------------------------

C_RED="\e[31m"
C_YELLOW="\e[33m"
C_GREEN="\e[32m"
C_PURPLE="\e[35m"
C_CYAN="\e[36m"
C_NORM="\e[0m"

LC_NUMERIC="en_US.UTF-8"

PARTYD_RUNNING=0
PARTYD_RESPONDING=0
PARTYMAN_VERSION=$(cat $PARTYMAN_GITDIR/VERSION)
DATA_DIR="$HOME/.darkpay"
DOWNLOAD_PAGE="https://github.com/DarkPayCoin/darkpay-core/releases/"
VERSION="tag/v0.18.0.7"

PARTYMAN_CHECKOUT=""
curl_cmd="timeout 7 curl -s -L -A partyman/$PARTYMAN_VERSION"
wget_cmd='wget --no-check-certificate -q'


# (mostly) functioning functions -- lots of refactoring to do ----------------

pending(){ [[ $QUIET ]] || ( echo -en "$C_YELLOW$1$C_NORM" && tput el ); }

ok(){ [[ $QUIET ]] || echo -e "$C_GREEN$1$C_NORM" ; }

warn() { [[ $QUIET ]] || echo -e "$C_YELLOW$1$C_NORM" ; }
highlight() { [[ $QUIET ]] || echo -e "$C_PURPLE$1$C_NORM" ; }

err() { [[ $QUIET ]] || echo -e "$C_RED$1$C_NORM" ; }
die() { [[ $QUIET ]] || echo -e "$C_RED$1$C_NORM" ; exit 1 ; }

quit(){ [[ $QUIET ]] || echo -e "$C_GREEN${1:-${messages["exiting"]}}$C_NORM" ; echo ; exit 0 ; }

confirm() { read -r -p "$(echo -e "${1:-${messages["prompt_are_you_sure"]} [y/N]}")" ; [[ ${REPLY:0:1} = [Yy] ]]; }

up()     { echo -e "\e[${1:-1}A"; }
clear_n_lines(){ for n in $(seq ${1:-1}) ; do tput cuu 1; tput el; done ; }

# check we're running bash 4 -------------------------------------------------

if [[ ${BASH_VERSION%%.*} != '4' ]];then
    die "partyman requires bash version 4. please update. exiting."
fi

# load language pack --------------------------------------------------------

SKELT0R_GITDIR=$(readlink -f $0)
declare -A messages

# set all default strings
source $SKELT0R_GITDIR/lang/en_US.sh

function install_darkpayd(){

    INSTALL_DIR=$HOME/darkpaycore
    DARKPAY_CLI="$INSTALL_DIR/darkpay-cli"

    if [ -e $INSTALL_DIR ] ; then
        die "\n - ${messages["preexisting_dir"]} $INSTALL_DIR ${messages["found"]} ${messages["run_reinstall"]} ${messages["exiting"]}"
    fi

    if [ -z "$UNATTENDED" ] ; then
        if [ $USER != "darkpay" ]; then
            echo
            warn "We stronly advise you run this installer under user "darkpay" with sudo access. Are you sure you wish to continue as $USER?"
            if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
                echo -e "${C_RED}${messages["exiting"]}$C_NORM"
                echo ""
                exit 0
            fi
        fi
        pending "${messages["download"]} $DOWNLOAD_URL\n${messages["and_install_to"]} $INSTALL_DIR?"
    else
        echo -e "$C_GREEN*** UNATTENDED MODE ***$C_NORM"
    fi

    if [ -z "$UNATTENDED" ] ; then
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi
    fi

    get_public_ips
    echo ""

    # prep it ----------------------------------------------------------------

    mkdir -p $INSTALL_DIR
    mkdir -p $DATA_DIR

    if [ ! -e $DATA_DIR/particl.conf ] ; then
        pending " --> ${messages["creating"]} $DATA_DIR/particl.conf... "

        while read; do
            eval echo "$REPLY"
        done < $PARTYMAN_GITDIR/particl.conf.template > "$DATA_DIR"/particl.conf
        ok "${messages["done"]}"
    fi

    # push it ----------------------------------------------------------------

    cd $INSTALL_DIR

    # pull it ----------------------------------------------------------------

    pending " --> ${messages["downloading"]} ${DOWNLOAD_URL}... "
    tput sc
    echo -e "$C_CYAN"
    $wget_cmd -O - $DOWNLOAD_URL | pv -trep -s27M -w80 -N wallet > $DOWNLOAD_FILE
    $wget_cmd -O - https://raw.githubusercontent.com/particl/gitian.sigs/master/$LATEST_VERSION-linux/tecnovert/particl-linux-$LATEST_VERSION-build.assert | pv -trep -w80 -N checksums > ${DOWNLOAD_FILE}.DIGESTS.txt
    echo -ne "$C_NORM"
    clear_n_lines 2
    tput rc
    clear_n_lines 3
    if [ ! -e $DOWNLOAD_FILE ] ; then
        echo -e "${C_RED}error ${messages["downloading"]} file"
        echo -e "tried to get $DOWNLOAD_URL$C_NORM"
        exit 1
    else
        ok ${messages["done"]}
    fi

    # prove it ---------------------------------------------------------------

    pending " --> ${messages["checksumming"]} ${DOWNLOAD_FILE}... "
    SHA256SUM=$( sha256sum $DOWNLOAD_FILE )
    SHA256PASS=$( grep $SHA256SUM ${DOWNLOAD_FILE}.DIGESTS.txt | wc -l )
    if [ $SHA256PASS -lt 1 ] ; then
        $wget_cmd -O - https://api.github.com/repos/particl/particl-core/releases | jq -r .[$LVCOUNTER] | jq .body > ${DOWNLOAD_FILE}.DIGESTS2.txt
        SHA256DLPASS=$( grep $SHA256SUM ${DOWNLOAD_FILE}.DIGESTS2.txt | wc -l )
        if [ $SHA256DLPASS -lt 1 ] ; then
            echo -e " ${C_RED} SHA256 ${messages["checksum"]} ${messages["FAILED"]} ${messages["try_again_later"]} ${messages["exiting"]}$C_NORM"
            exit 1
        fi
    fi
    ok "${messages["done"]}"

    # produce it -------------------------------------------------------------

    pending " --> ${messages["unpacking"]} ${DOWNLOAD_FILE}... " && \
    tar zxf $DOWNLOAD_FILE && \
    ok "${messages["done"]}"

    # pummel it --------------------------------------------------------------

    if [ $PARTYD_RUNNING == 1 ]; then
        pending " --> ${messages["stopping"]} partcld. ${messages["please_wait"]}"
        $PARTY_CLI stop >/dev/null 2>&1
        sleep 15
        killall -9 particld particl-shutoff >/dev/null 2>&1
        ok "${messages["done"]}"
    fi

    # place it ---------------------------------------------------------------

    mv particl-$LATEST_VERSION/bin/particld particld-$LATEST_VERSION
    mv particl-$LATEST_VERSION/bin/particl-cli particl-cli-$LATEST_VERSION
    if [ $ARM != 1 ];then
        mv particl-$LATEST_VERSION/bin/particl-qt particl-qt-$LATEST_VERSION
    fi
    ln -s particld-$LATEST_VERSION particld
    ln -s particl-cli-$LATEST_VERSION particl-cli
    if [ $ARM != 1 ];then
        ln -s particl-qt-$LATEST_VERSION particl-qt
    fi

    # permission it ----------------------------------------------------------

    if [ ! -z "$SUDO_USER" ]; then
        chown -h $USER:$USER {$DOWNLOAD_FILE,${DOWNLOAD_FILE}.DIGESTS.txt,particl-cli,particld,particl-qt,particl*$LATEST_VERSION}
    fi

    # purge it ---------------------------------------------------------------

    rm -rf particl-$LATEST_VERSION

    # path it ----------------------------------------------------------------

    pending " --> adding $INSTALL_DIR PATH to ~/.bash_aliases ... "
    if [ ! -f ~/.bash_aliases ]; then touch ~/.bash_aliases ; fi
    sed -i.bak -e '/partyman_env/d' ~/.bash_aliases
    echo "export PATH=$INSTALL_DIR:\$PATH; # partyman_env" >> ~/.bash_aliases
    ok "${messages["done"]}"

    # autoboot it ------------------------------------------------------------

    INIT=$(ps --no-headers -o comm 1)
    if [ $INIT == "systemd" ] && [ "$USER" == "particl" ] && [ ! -z "$SUDO_USER" ]; then
        pending " --> detecting $INIT for auto boot ($USER) ... "
        ok ${messages["done"]}
        DOWNLOAD_SERVICE="https://raw.githubusercontent.com/particl/particl-core/master/contrib/init/particld.service"
        pending " --> [systemd] ${messages["downloading"]} ${DOWNLOAD_SERVICE}... "
        $wget_cmd -O - $DOWNLOAD_SERVICE | pv -trep -w80 -N service > particld.service
        if [ ! -e particld.service ] ; then
           echo -e "${C_RED}error ${messages["downloading"]} file"
           echo -e "tried to get particld.service$C_NORM"
        else
           ok ${messages["done"]}
        pending " --> [systemd] installing service ... "
        if sudo cp -rf particld.service /etc/systemd/system/; then
            ok ${messages["done"]}
        fi
           pending " --> [systemd] reloading systemd service ... "
        if sudo systemctl daemon-reload; then
            ok ${messages["done"]}
        fi
           pending " --> [systemd] enable particld system startup ... "
        if sudo systemctl enable particld; then
               ok ${messages["done"]}
           fi
        fi
    fi

    # poll it ----------------------------------------------------------------

    _get_versions

    # pass or punt -----------------------------------------------------------

    if [ $LATEST_VERSION == $CURRENT_VERSION ]; then
        echo -e ""
        echo -e "${C_GREEN}Particl ${LATEST_VERSION} ${messages["successfully_installed"]}$C_NORM"

        echo -e ""
        echo -e "${C_GREEN}${messages["installed_in"]} ${INSTALL_DIR}$C_NORM"
        echo -e ""
        ls -l --color {$DOWNLOAD_FILE,${DOWNLOAD_FILE}.DIGESTS.txt,particl-cli,particld,particl-qt,particl*$LATEST_VERSION}
        echo -e ""

        if [ ! -z "$SUDO_USER" ]; then
            echo -e "${C_GREEN}Symlinked to: ${LINK_TO_SYSTEM_DIR}$C_NORM"
            echo -e ""
            ls -l --color $LINK_TO_SYSTEM_DIR/{particld,particl-cli}
            echo -e ""
        fi

    else
        echo -e "${C_RED}${messages["particl_version"]} $CURRENT_VERSION ${messages["is_not_uptodate"]} ($LATEST_VERSION) ${messages["exiting"]}$C_NORM"
        exit 1
    fi
}
