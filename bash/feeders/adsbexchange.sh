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

## VARIABLES

BUILDDIR=$PWD
ADSBEXCHANGEDIR="$BUILDDIR/adsbexchange"

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

## CONFIGURE SCRIPT TO EXECUTE NETCAT TO FEED ADS-B EXCHANGE

echo -e "\033[33mSetting permissions on adsbexchange-maint.sh..."
echo -e "\033[37m"
sudo chmod +x $ADSBEXCHANGEDIR/adsbexchange-maint.sh

echo -e "\033[33mAdding startup line to rc.local..."
echo -e "\033[37m"
lnum=($(sed -n '/exit 0/=' /etc/rc.local))
((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${ADSBEXCHANGEDIR}/adsbexchange-maint.sh &\n" /etc/rc.local

## START NETCAT ADS-B EXCHANGE FEED

echo -e "\033[33mExecuting adsbexchange-maint.sh..."
echo -e "\033[37m"
sudo $ADSBEXCHANGEDIR/adsbexchange-maint.sh &

echo -e "\033[33mConfiguration of the ADS-B Exchange feed is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE
