#!/bin/sh
# This script was slightly adapted from https://github.com/AsamK/signal-cli/

SIGNAL_VERSION="0.13.4"

clear
# Install java
zypper -n install java-21-openjdk

# Install signal cli
wget -c https://github.com/AsamK/signal-cli/releases/download/v"${SIGNAL_VERSION}"/signal-cli-"${SIGNAL_VERSION}".tar.gz
tar zxvf signal-cli-"${SIGNAL_VERSION}".tar.gz -C /opt
ln -sf /opt/signal-cli-"${SIGNAL_VERSION}"/bin/signal-cli /usr/bin


signal-cli --version > /dev/null 2>&1
RETVAL=$?

if [[ "$RETVAL" = "0" ]];
then
cat <<ET

Congratulations, You have installed signal-cli version: ${SIGNAL_VERSION}


Don't forget to register your number first:

signal-cli -a ACCOUNT register

ET

else
cat <<ET

Sorry, but it looks like something went wrong.  Please install manually. 

See: https://github.com/AsamK/signal-cli

ET


fi
