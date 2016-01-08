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

BUILDDIR=$PWD
BASHDIR=$BUILDDIR/../bash

source ../bash/functions.sh

clear

echo -e "\033[31m"
echo "-------------------------------------------"
echo " Now ready to install dump1090-portal."
echo "-------------------------------------------"
echo -e "\033[33mThe goal of the dump1090-portal portal project is to create a very"
echo "light weight easy to manage web interface for dump-1090 installations"
echo "This project is at the moment very young with only a few of the planned"
echo "featured currently available at this time."
echo ""
echo "https://github.com/jprochazka/dump1090-portal"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

clear

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage cron
CheckPackage collectd
CheckPackage rrdtool

echo -e "\033[33m"
echo "Installing homepage..."
echo -e "\033[37m"
chmod +x $BASHDIR/portal/homepage.sh
$BASHDIR/portal/homepage.sh

echo -e "\033[33m"
echo "Installing map container..."
echo -e "\033[37m"
chmod +x $BASHDIR/portal/map.sh
$BASHDIR/portal/map.sh

echo -e "\033[33m"
echo "Installing performance graphs..."
echo -e "\033[37m"
chmod +x $BASHDIR/portal/graphs.sh
$BASHDIR/portal/graphs.sh

if [ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
    echo -e "\033[33m"
    echo "Installing performance graphs..."
    echo -e "\033[37m"
    chmod +x $BASHDIR/portal/planefinder.sh
    $BASHDIR/portal/planefinder.sh
fi

echo -e "\033[33m"
echo "Installation and configuration of the performance graphs is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE
