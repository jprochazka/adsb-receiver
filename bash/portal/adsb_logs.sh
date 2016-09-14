#!/bin/bash

#####################################################################################
#                                   ADS-B RECEIVER                                  #
#####################################################################################
#                                                                                   #
#  A set of scripts created to automate the process of installing the software      #
#  needed to setup a Mode S decoder as well as feeders which are capable of         #
#  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
#                                                                                   #
#  Project Hosted On GitHub: https://github.com/jprochazka/adsb-receiver            #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015-2016 Joseph A. Prochazka                                       #
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

PROJECTROOTDIRECTORY="$PWD"
BASHDIRECTORY="$PROJECTROOTDIRECTORY/bash"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
PORTALBUILDDIRECTORY="$BUILDDIRECTORY/portal"

# Fronttail Logging Installation

# echo -e "\033[33m"
# echo -e "Installing logging software...\033[37m"
# echo -e "Node and essential build tools installed..."
# echo -e "Installing frontail...\033[37m"
# sudo curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
# sudo apt-get install -y nodejs
# sudo apt-get install -y build-essential
# sudo npm install frontail -g
# echo -e "Successfully installed node and frontail..."

# EXECUTE THE LOGGING SCRIPTS
function AddPiAware() {
  echo -e "\e[94m  Adding PiAware logs...\e[97m"
  if [ ! -d "$PROJECTROOTDIRECTORY/logs" ] ; then sudo mkdir $PROJECTROOTDIRECTORY/logs ;
fi
  sudo ln -s /var/log/piaware.log $PROJECTROOTDIRECTORY/logs/piaware.log
}

function AddPlaneFinder() {
  echo -e "\e[94m  Adding PlaneFinder logs...\e[97m"
  if [ ! -d "$PROJECTROOTDIRECTORY/logs" ] ; then sudo mkdir $PROJECTROOTDIRECTORY/logs ;
fi
  sudo ln -s /var/log/pfclient/*.log $PROJECTROOTDIRECTORY/logs/*.log
}

function AddFR24() {
  echo -e "\e[94m  Adding FlightRadar24 logs...\e[97m"
  if [ ! -d "$PROJECTROOTDIRECTORY/logs" ] ; then sudo mkdir $PROJECTROOTDIRECTORY/logs ;
fi
  sudo ln -s /var/log/fr24feed.log $PROJECTROOTDIRECTORY/logs/fr24feed.log
}

function AddDump1090() {
  echo -e "\e[94m  Adding dump1090-mutability logs...\e[97m"
  if [ ! -d "$PROJECTROOTDIRECTORY/logs" ] ; then sudo mkdir $PROJECTROOTDIRECTORY/logs ;
fi
  sudo ln -s /var/log/dump1090-mutability.log $PROJECTROOTDIRECTORY/logs/dump1090-mutability.log
}

function AddDump978() {
  echo -e "\e[94m  Adding dump978 logs...\e[97m"
  if [ ! -d "$PROJECTROOTDIRECTORY/logs" ] ; then sudo mkdir $PROJECTROOTDIRECTORY/logs ;
fi
  sudo ln -s /var/log/dump978.log $PROJECTROOTDIRECTORY/logs/dump978
}

declare LOGCHOICES
# Message displayed above feeder selection checklist for logging.

# Check if the PiAware package is installed or if it needs upgraded.
  if [ $(dpkg-query -W -f='${STATUS}' piaware 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
      # The PiAware package appears to be installed.
      LOGFILEOPTIONS=("${LOGFILEOPTIONS[@]}" '/var/log/piaware.log' '' OFF)
fi

# Check if the Plane Finder ADS-B Client package is installed.
  if [ $(dpkg-query -W -f='${STATUS}' pfclient 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
      # The Plane Finder ADS-B Client package appears to be installed.
      LOGFILEOPTIONS=("${LOGFILEOPTIONS[@]}" '/var/log/pfclient/*.log' '' OFF)
fi

# Check if the Flightradar24 client package is installed.
  if [ $(dpkg-query -W -f='${STATUS}' fr24feed 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
      # The Flightradar24 client package appears to be installed.
      LOGFILEOPTIONS=("${LOGFILEOPTIONS[@]}" '/var/log/fr24feed.log' '' OFF)
fi

# Check if the dump1090-mutability package is installed.
  if [ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]; then
      # The dump1090-mutability package appear to be installed.
      LOGFILEOPTIONS=("${LOGFILEOPTIONS[@]}" '/var/log/dump1090-mutability.log' '' OFF)
fi

# Check if dump978 package is installed
  if [ -f $BUILDDIR/dump978/dump978 ] && [ -f $BUILDDIR/dump978/uat2text ] && [ -f $BUILDDIR/dump978/uat2esnt ] && [ -f $BUILDDIR/dump978/uat2json ]; then
    # The dump978 package appear to be installed.
    LOGFILEOPTIONS=("${LOGFILEOPTIONS[@]}" '/var/log/dump978.log' '' OFF)
fi

LOGFILESAVAILABLE="The following feeders are installed and can be tailed for log analysis. Choose the feeders you wish to tail the log files for. (Hint: Use spacebar to select/deselect.)"

  if [[ -n "$LOGFILEOPTIONS" ]]; then
      # Display a checklist containing feeders that are not installed if any.
      # This command is creating a file named LOGCHOICES but can not figure out how to make it only a variable without the file being created at this time.
      whiptail --backtitle "$BACKTITLE" --title "Feeder Installation Options" --checklist --nocancel --separate-output "$LOGFILESAVAILABLE" 13 52 4 "${LOGFILEOPTIONS[@]}" 2>LOGCHOICES
fi

LOGDUMP1090=1
LOGPLANEFINDER=1
LOGFR24=1
LOGDUMP1090=1
LOGDUMP978=1

if [ -s LOGCHOICES ]; then
    while read LOGCHOICES
    do
        case $LOGCHOICES in
            "/var/log/piaware.log")
              LOGPIAWARE=0
              ;;
            "/var/log/pfclient/*.log")
                LOGPLANEFINDER=0
            ;;
            "/var/log/fr24feed.log")
                LOGFR24=0
            ;;
            "/var/log/dump1090-mutability.log")
                LOGDUMP1090=0
            ;;
            "/var/log/dump978.log")
                LOGDUMP978=0
            ;;

        esac
    done < LOGCHOICES
fi

  if [ "$LOGPIAWARE" = 0 ]; then
      AddPiAware
fi

  if [ "$LOGPLANEFINDER" = 0 ]; then
      AddPlaneFinder
fi

    if [ "$LOGFR24" = 0 ]; then
      AddFR24
fi

    if [ "$LOGDUMP1090" = 0 ]; then
      AddDump1090
fi

    if [ "$LOGDUMP978" = 0 ]; then
      AddDump978
fi

# Add frontail logging script to rc.local.
echo -e "Adding startup line to rc.local...\033[37m"
lnum=($(sed -n '/exit 0/=' /etc/rc.local))
((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i frontail -d  --ui-hide-topbar default $PROJECTROOTDIRECTORY/logs/*.log &\n" /etc/rc.local

# Start frontail.
echo -e "\033[33m"
echo -e "Starting frontail logging...\033[37m"
nohup frontail -d  --ui-hide-topbar default $PROJECTROOTDIRECTORY/logs/*.log > /dev/null 2>&1 &

# Remove the now unneeded
echo -e "Removing the unnecessary LOGCHOICES file now..."
rm -f LOGCHOICES

# Display the installation complete message box.
echo -e "Realtime Log Streaming Setup Complete"

exit 0
