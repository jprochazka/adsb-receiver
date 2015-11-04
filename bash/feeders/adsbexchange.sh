#!/bin/bash

#####################################################################################
#                                   ADS-B FEEDER                                    #
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

BUILDDIR=${PWD}

clear

echo -e "\033[31m"
echo "-----------------------------------------------------"
echo " Now ready to set up ADS-B Exchange feed."
echo "-----------------------------------------------------"
echo -e "\033[33mADSBexchange.com is a co-op of ADS-B/Mode S/MLAT feeders from around the world."
echo "PiAware is required to be installed in order to feed this site. If PiAware is not"
echo "currently installed this script will execute the PiAware installation script after"
echo "which this script will continue with the ADS-B Exchange feed setup."
echo ""
echo "http://www.adsbexchange.com/how-to-feed/"
echo "https://github.com/flightaware/piaware"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK THAT PIAWARE IS INSTALLED

echo -e "\e[33m"
printf "Checking if the package piaware is installed..."
if [ $(dpkg-query -W -f='${Status}' piaware 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo -e "\033[31m [NOT INSTALLED]"
    echo -e "\033[33mPiAware does not appear to be installed."
    echo "PiAware is required in order to feed data to adsbexchange.com."
    echo -e "\033[37m"
    read -p "Press enter to install PiAware..." CONTINUE
    echo -e "\e[33m"
    echo "Executing the PiAware installation script..."
    echo -e "\033[37m"
    chmod 755 ../bash/piaware.sh
    ../bash/piaware.sh
else
    echo -e "\033[32m [OK]\033[37m"
    echo ""
fi

## CONFIGURE PIAWARE TO FEED ADS-B EXCHANGE

echo -e "\033[33mAdding the ADS-B Exchange feed to PiAware's configuration..."
echo -e "\033[37m"
MLATRESULTFORMAT=`sudo piaware-config -show | grep mlatResultsFormat`
ORIGINALFORMAT=`sed 's/mlatResultsFormat //g' <<< $MLATRESULTFORMAT`
COMMAND=`sudo piaware-config -mlatResultsFormat "${ORIGINALFORMAT} beast,connect,feed.adsbexchange.com:30005"`
$COMMAND
sudo piaware-config -restart

## ADD SCRIPT TO EXECUTE NETCAT TO FEED ADS-B EXCHANGE

echo -e "\033[33mDownloading ADS-B Exchange maintainance script..."
echo -e "\033[37m"
mkdir $BUILDDIR/adsbexchange/
wget http://bucket.adsbexchange.com/adsbexchange-maint.sh -O $BUILDDIR/adsbexchange/adsbexchange-maint.sh

echo -e "\033[33mSetting permissions and updating rc.d..."
echo -e "\033[37m"
sudo chmod 755 $BUILDDIR/adsbexchange/adsbexchange-maint.sh

echo -e "\033[33mAdding startup line to rc.local..."
echo -e "\033[37m"
lnum=($(sed -n '/exit 0/=' /etc/rc.local))
((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${BUILDDIR}/adsbexchange-maint.sh &\n" /etc/rc.local

## START NETCAT ADS-B EXCHANGE FEED

echo -e "\033[33mRunning ADS-B Exchange startup script..."
echo -e "\033[37m"
sudo $BUILDDIR/adsbexchange/adsbexchange-maint.sh start > /dev/null & 

echo -e "\033[33mConfiguration of the ADS-B Exchange feed is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE
