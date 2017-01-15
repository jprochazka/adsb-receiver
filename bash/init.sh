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

### VARIABLES

PROJECT_ROOT_DIRECTORY="$PWD"
BASH_DIRECTORY="$PROJECT_ROOT_DIRECTORY/bash"
BUILD_DIRECTORY="$PROJECT_ROOT_DIRECTORY/build"

### INCLUDE EXTERNAL SCRIPTS

source $BASH_DIRECTORY/functions.sh

### MORE VARIABLES

export PROJECT_TITLE="The ADS-B Receiver Project Installer"
export PROJECT_GITHUB="https://github.com/jprochazka/adsb-receiver"
export PROJECT_WEBSITE="https://www.adsbreceiver.net"
export ADSB_PROJECTTITLE="$PROJECT_TITLE"
TERMINATEDMESSAGE="  \e[91m  ANY FURTHER SETUP AND/OR INSTALLATION REQUESTS HAVE BEEN TERMINIATED\e[39m"

# Set git branch to master if not already specified.
if [[ -z "${PROJECTBRANCH}" ]] ; then
    PROJECTBRANCH="master"
fi

### CHECK IF THIS IS THE FIRST RUN USING THE IMAGE RELEASE

if [ -f $PROJECT_ROOT_DIRECTORY/image ]; then
    # Enable extra confirmation dialogs.
    VERBOSE="true"
    # Execute image setup script.
    chmod +x $BASH_DIRECTORY/image.sh
    $BASH_DIRECTORY/image.sh
    if [ $? -ne 0 ]; then
        echo -e ""
        echo -e $TERMINATEDMESSAGE
        echo -e ""
        exit 1
    else 
        exit 0
    fi
fi

### FUNCTIONS

# Only call AptUpdate if last update was more than $APT_UPDATE_THRESHOLD seconds ago.
APT_UPDATE_THRESHOLD="1800"
APT_UPDATE_CURRENT_EPOCH=`date +%s`
APT_UPDATE_LAST_EPOCH=`stat -c %Y /var/cache/apt/pkgcache.bin`
APT_UPDATE_DELTA=`echo $[${APT_UPDATE_CURRENT_EPOCH} - ${APT_UPDATE_LAST_EPOCH}]`
if [[ "${APT_UPDATE_DELTA}" -gt "${APT_UPDATE_THRESHOLD}" ]] ; then
    AptUpdate
fi

CheckPrerequisites
UpdateRepository
RandomDelay

### DISPLAY WELCOME SCREEN

### ASK IF OPERATING SYSTEM SHOULD BE UPDATED

if (whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Operating System Updates" --yesno "It is recommended that you update your system before building and/or installing any ADS-B receiver related packages. This script can do this for you at this time if you like.\n\nWould you like to update your operating system now?" 11 78) then
    UpdateOperatingSystem
fi

### EXECUTE BASH/MAIN.SH

chmod +x $BASH_DIRECTORY/main.sh
$BASH_DIRECTORY/main.sh
# Catch unclean exits.
if [ $? -ne 0 ]; then
    echo -e ""
    echo -e $TERMINATEDMESSAGE
    echo -e ""
    exit 1
fi

### INSTALLATION COMPLETE

# Display the installation complete message box.
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Software Installation Complete" --msgbox "INSTALLATION COMPLETE\n\nDO NOT DELETE THIS DIRECTORY!\n\nFiles needed for certain items to run properly are contained within this directory. Deleting this directory may result in your receiver not working properly.\n\nHopefully, these scripts and files were found useful while setting up your ADS-B Receiver. Feedback regarding this software is always welcome. If you have any issues or wish to submit feedback, feel free to do so on GitHub.\n\n ${PROJECT_GITHUB}" 20 65

# Unset any exported variables.
unset PROJECT_TITLE
unset PROJECT_GITHUB
unset PROJECT_WEBSITE
unset ADSB_PROJECTTITLE

# Remove the FEEDERCHOICES file created by whiptail.
if [[ -f FEEDERCHOICES ]] ; then
    rm -f FEEDERCHOICES
fi

echo -e "\033[32m"
echo "Installation complete."
echo -e "\033[37m"

exit 0
