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

#################################################################################
# UPDATE REPOSITORY PACKAGE LISTS
function AptUpdate() {
    clear
    echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Downloading the latest package lists for all enabled repositories and PPAs..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    sudo apt-get update
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Finished downloading and updating package lists.\e[39m"
    echo ""
    if [[ ! -z ${VERBOSE} ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
}

#################################################################################
# UPDATE THE OPERATING SYSTEM
function UpdateOperatingSystem() {
    clear
    echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Downloading and installing the latest updates for your operating system..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    sudo apt-get -y dist-upgrade
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Your operating system should now be up to date.\e[39m"
    echo ""
    if [[ ! -z ${VERBOSE} ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
}

#################################################################################
# Detect if a package is installed and if not attempt to install it.

function CheckPackage {
    ATTEMPT=1
    MAXATTEMPTS=5
    WAITTIME=5

    while (( $ATTEMPT -le `(($MAXATTEMPTS + 1))` )); do

        # If the maximum attempts has been reached...
        if [ $ATTEMPT -gt $MAXATTEMPTS ]; then
            echo ""
            echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
            echo -e "  UNABLE TO INSTALL A REQUIRED PACKAGE."
            echo -e "  SETUP HAS BEEN TERMINATED!"
            echo ""
            echo -e "\e[93mThe package \"$1\" could not be installed in $MAXATTEMPTS attempts.\e[39m"
            echo ""
            exit 1
        fi

        # Check if the package is already installed.
        printf "\e[94m  Checking if the package $1 is installed..."
        if [ $(dpkg-query -W -f='${STATUS}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then

            # If this is not the first attempt at installing this package...
            if [ $ATTEMPT -gt 1 ]; then
                echo -e "\e[91m  \e[5m[INSTALLATION ATTEMPT FAILED]\e[25m"
                echo -e "\e[94m  Attempting to Install the package $1 again in $WAITTIME seconds (ATTEMPT $ATTEMPT OF $MAXATTEMPTS)..."
                sleep $WAITTIME
            else
                echo -e "\e[91m [NOT INSTALLED]"
                echo -e "\e[94m  Installing the package $1..."
            fi

            # Attempt to install the required package.
            echo -e "\e[97m"
            ATTEMPT=$((ATTEMPT+1))
            sudo apt-get install -y $1
            echo -e "\e[39m"
        else
            # The package appears to be installed.
            echo -e "\e[92m [OK]\e[39m"
            break
        fi
    done
}

#################################################################################
# CHECK PREREQUISITES
function CheckPrerequisites() {
    clear
    echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Checking to make sure the whiptail and git packages are installed..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    CheckPackage whiptail
    CheckPackage git
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  The whiptail and git packages are installed.\e[39m"
    echo ""
    if [[ ! -z ${VERBOSE} ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
}

#################################################################################
# UPDATE GIT REPOSITORY
function UpdateRepository() {
    clear
    echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
    echo ""
    echo -e "\e[92m  Pulling the latest version of the $ADSB_PROJECTTITLE git repository..."
    echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[97m"
    echo ""
    echo -e "\e[94m  Switching to branch $PROJECTBRANCH...\e[97m"
    echo ""
    git checkout $PROJECTBRANCH
    echo ""
    git remote update
    echo ""
    if [[ `git status -uno | grep -c "is behind"` -gt 0 ]] ; then
       echo -e "\e[94m  Pulling the latest git repository...\e[97m"
       git pull
    else
       echo -e "\e[94m  Local install matches the latest git repository...\e[97m"
    fi
    echo ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  Finished pulling the latest version of the $ADSB_PROJECTTITLE git repository....\e[39m"
    echo ""
    if [[ ! -z ${VERBOSE} ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
}

#################################################################################
# Change a setting in a configuration file.
# The function expects 3 parameters to be passed to it in the following order.
# ChangeConfig KEY VALUE FILE

function ChangeConfig {
    # Use sed to locate the "KEY" then replace the "VALUE", the portion after the equals sign, in the specified "FILE".
    # This function should work with any configuration file with settings formated as KEY="VALUE".
    sudo sed -i "s/\($1 *= *\).*/\1\"$2\"/" $3
}

function GetConfig {
    # Use sed to locate the "KEY" then read the "VALUE", the portion after the equals sign, in the specified "FILE".
    # This function should work with any configuration file with settings formated as KEY="VALUE".
    echo `sed -n "/^$1 *= *\"\(.*\)\"$/s//\1/p" $2`
}

function CommentConfig {
    # Use sed to locate the "KEY" then comment out the line containing it in the specified "FILE".
    sudo sed -i -e "/$1/s/^#*/#/" $2
}

function UncommentConfig {
    # Use sed to locate the "KEY" then uncomment the line containing it in the specified "FILE".
    sudo sed -i -e "/$1/s/^#//" $2
}

#################################################################################
# The following function is used to clean up the log files by removing
# any color escaping sequences from the log file so it is easier to read.
# There are other lines not needed which can be removed as well.

function CleanLogFile {
    # Use sed to remove any color sequences from the specified "FILE".
    sed -i "s,\x1B\[[0-9;]*[a-zA-Z],,g" $1
    # Remove the "Press enter to continue..." lines from the log file.
    sed -i "/Press enter to continue.../d" $1
}

#################################################################################
# Add a pseudo-random delay of between 5 and 59 minutes

function RandomDelay() {
    if [[ ${DELAY} = "true" ]] ; then
        DELAY_TIME=`echo "(( 300 + ( $RANDOM + $RANDOM )) / 20 )" | bc`
        DATE=`date`
        echo -e ""
        echo -e "\e[91m  $ADSB_PROJECTTITLE"
        echo -e ""
        echo -en "\e[92m  Pausing for ${DELAY_TIME} seconds from: \t\e[39m $DATE"
        echo -e ""
        sleep $DELAY_TIME
    fi
}
