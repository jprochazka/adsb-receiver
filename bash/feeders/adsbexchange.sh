#!/bin/bash

#####################################################################################
#                                  ADS-B RECEIVER                                   #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015 Joseph A. Prochazka                                            #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


##########################################################################################
# TODO                                                                                   #
#----------------------------------------------------------------------------------------#
#                                                                                        #
# Get receiver latitude and longitude from the dump1090-mutability config file.          #
# Figure out the altitude using latitude and longitude.                                  #
# Ask the user for their ADS-B Exchange user name to be used in the mlat-client command. #
# Remove line pertaining to adsbexchange-maint.sh from the file /etc/rc.local.           #
#                                                                                        #
##########################################################################################


## VARIABLES

BUILDDIR=$PWD
MLATCLIENTDIR="$BUILDDIR/mlat-client"
ADSBEXCHANGEDIR="$BUILDDIR/adsbexchange"

source ../bash/variables.sh
source ../bash/functions.sh

## INFORMATIVE MESSAAGE ABOUT THIS SOFTWARE

clear

echo -e "\033[31m"
echo "-----------------------------------------------------"
echo " Now ready to set up a feed to ADS-B Exchange."
echo "-----------------------------------------------------"
echo -e "\033[33mADSBexchange.com is a co-op of ADS-B/Mode S/MLAT feeders from around the world."
echo ""
echo "http://www.adsbexchange.com/how-to-feed/"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to fulfill dependencies..."
echo -e "\033[37m"
CheckPackage netcat
CheckPackage build-essential
CheckPackage debhelper
CheckPackage python3-dev

## DOWNLOAD OR UPDATE THE MLAT-CLIENT SOURCE

# Check if the git repository already exists locally.
if [ -d $MLATCLIENTDIR ] && [ -d $MLATCLIENTDIR/.git ]; then
    # A directory with a git repository containing the source code exists.
    echo -e "\033[33m"
    echo "Updating the local mlat-client git repository..."
    echo -e "\033[37m"
    cd $MLATCLIENTDIR
    git pull
    git checkout tags/${MLATCLIENTTAG}
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\033[33m"
    echo "Cloning the mlat-client git repository locally..."
    echo -e "\033[37m"
    git clone https://github.com/mutability/mlat-client.git
    cd $MLATCLIENTDIR
    git checkout tags/${MLATCLIENTTAG}
fi

## BUILD AND INSTALL THE MLAT-CLIENT PACKAGE

echo -e "\033[33m"
echo "Building the mlat-client package..."
echo -e "\033[37m"
dpkg-buildpackage -b -uc

echo -e "\033[33m"
echo "Installing the mlat-client package..."
echo -e "\033[37m"
sudo dpkg -i ${BUILDDIR}/mlat-client_${MLATCLIENTVERSION}*.deb

## CONFIGURE SCRIPT TO EXECUTE AND MAINTAIN MLAT-CLIENT AND NETCAT TO FEED ADS-B EXCHANGE

# Create the adsbexchange directory in the build directory if it does not exist.
if [ ! -d "$ADSBEXCHANGEDIR" ]; then
    mkdir $ADSBEXCHANGEDIR
fi

echo -e "\033[33mCreating the file adsbexchange-netcat_maint.sh..."
echo -e "\033[37m"
tee -a $ADSBEXCHANGEDIR/adsbexchange-netcat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    sleep 30
    /bin/nc 127.0.0.1 30005 | /bin/nc feed.adsbexchange.com 30005
  done
EOF

echo -e "\033[33mCreating the file adsbexchange-mlat_maint.sh..."
echo -e "\033[37m"
tee -a $ADSBEXCHANGEDIR/adsbexchange-mlat_maint.sh > /dev/null <<EOF
#! /bin/sh
while true
  do
    sleep 30
    /usr/bin/mlat-client --input-type beast --input-connect localhost:300 --lat - $RECEIVERLAT --lon $RECEIVERLON --alt $RECEIVERALT --user $ADSBECHANGEUSER --server feed.adsbexchange.com:31090 --no-udp
  done
EOF

echo -e "\033[33mSetting permissions on adsbexchange-netcat_maint.sh..."
echo -e "\033[37m"
sudo chmod +x $ADSBEXCHANGEDIR/adsbexchange-netcat_maint.sh

echo -e "\033[33mSetting permissions on adsbexchange-mlat_maint.sh..."
echo -e "\033[37m"
sudo chmod +x $ADSBEXCHANGEDIR/adsbexchange-mlat_maint.sh

echo -e "\033[33mAdding netcat startup line to rc.local..."
echo -e "\033[37m"
lnum=($(sed -n '/exit 0/=' /etc/rc.local))
((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${ADSBEXCHANGEDIR}/adsbexchange-netcat_maint.sh &\n" /etc/rc.local

echo -e "\033[33mAdding mlat-client startup line to rc.local..."
echo -e "\033[37m"
lnum=($(sed -n '/exit 0/=' /etc/rc.local))
((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${ADSBEXCHANGEDIR}/adsbexchange-mlat_maint.sh &\n" /etc/rc.local

## START THE MLAT-CLIENT AND NETCAT FEED

echo -e "\033[33mExecuting adsbexchange-netcat_maint.sh..."
echo -e "\033[37m"
sudo $ADSBEXCHANGEDIR/adsbexchange-netcat_maint.sh &

echo -e "\033[33mExecuting adsbexchange-mlat_maint.sh..."
echo -e "\033[37m"
sudo $ADSBEXCHANGEDIR/adsbexchange-mlat_maint.sh &

echo -e "\033[33mConfiguration of the ADS-B Exchange feed is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE
