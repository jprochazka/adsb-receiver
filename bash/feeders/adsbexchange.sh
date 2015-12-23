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

## CONFIGURE PIAWARE TO FEED ADS-B EXCHANGE IF PIAWARE IS INSTALLED

echo -e "\e[33m"
printf "Configuring PiAware if it is installed..."
if [ $(dpkg-query -W -f='${Status}' piaware 2>/dev/null | grep -c "ok installed") != 0 ]; then
    echo -e "\033[33m"
    echo "Adding the ADS-B Exchange feed to PiAware's configuration..."
    ORIGINALFORMAT=`sudo piaware-config -show | grep mlatResultsFormat | sed 's/mlatResultsFormat //g'`
    MLATRESULTS=`sed 's/[{}]//g' <<< $ORIGINALFORMAT`
    CLEANFORMAT=`sed 's/ beast,connect,feed.adsbexchange.com:30005//g' <<< $MLATRESULTS`
    sudo piaware-config -mlatResultsFormat "${CLEANFORMAT} beast,connect,feed.adsbexchange.com:30005"
    echo "Restarting PiAware so new configuration takes effect..."
    echo -e "\033[37m"
    sudo piaware-config -restart
    echo ""
fi

## CONFIGURE SCRIPT TO EXECUTE NETCAT TO FEED ADS-B EXCHANGE

echo -e "\033[33mSetting permissions on adsbexchange-maint.sh..."
echo -e "\033[37m"
sudo chmod +x $BUILDDIR/adsbexchange/adsbexchange-maint.sh

echo -e "\033[33mAdding startup line to rc.local..."
echo -e "\033[37m"
lnum=($(sed -n '/exit 0/=' /etc/rc.local))
((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${BUILDDIR}/adsbexchange/adsbexchange-maint.sh &\n" /etc/rc.local

## START NETCAT ADS-B EXCHANGE FEED

echo -e "\033[33mExecuting adsbexchange-maint.sh..."
echo -e "\033[37m"
sudo $BUILDDIR/adsbexchange/adsbexchange-maint.sh &

echo -e "\033[33mConfiguration of the ADS-B Exchange feed is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE
