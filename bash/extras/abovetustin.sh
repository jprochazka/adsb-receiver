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

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

#################################################################################
# Detect CPU Architecture.

function Check_CPU () {
    if [[ -z "${CPU_ARCHITECTURE}" ]] ; then
        echo -en "\e[94m  Detecting CPU architecture...\e[97m"
        CPU_ARCHITECTURE=`uname -m | tr -d "\n\r"`
    fi
}

### BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo ""
echo -e "\e[92m  Setting up AboveTustin..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "AboveTustin Setup" --yesno "AboveTustin is an ADS-B Twitter Bot. Uses dump1090-mutability to track airplanes and then tweets whenever an airplane flies overhead.\n\n  https://github.com/kevinabrandon/AboveTustin\n\nContinue setting up AboveTustin?" 13 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo ""
        echo -e "\e[93m----------------------------------------------------------------------------------------------------"
        echo -e "\e[92m  AboveTustin setup halted.\e[39m"
        echo ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

### CHECK IF A PHANTOMJS ALREADY EXISTS OR IF A PRECOMPILED BINARY IS AVAILABLE FOR THIS DEVICE

echo -e "\e[95m  Checking for PhantomJS...\e[97m"
echo ""
if [[ -f "/usr/bin/phantomjs" ]] && [[ "`phantomjs --version`" -eq "${PHANTOMJS_VERSION}" ]] ; then
    # A PhantomJS binary which is the proper version appears to exist on this device.
    echo -e "\e[94m  PhantomJS is present on this device and is the proper version...\e[97m"
    PHANTOMJS_EXISTS="true"
else
    echo -e "\e[91m  PhantomJS is not present on this device or is not the proper version...\e[97m"
    PHANTOMJS_EXISTS="false"

    # Use function to detect cpu architecture.
    Check_CPU
    echo -e "\e[94m  \"${CPU_ARCHITECTURE}\"...\e[97m"

    if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "x86_64" ]] || [[ "${CPU_ARCHITECTURE}" = "i686" ]] ; then
        # A precompiled binary should be available for this device.
        echo -e "\e[94m  A precompiled PhantomJS binary appears to be available for this CPU's arcitecture...\e[97m"
        BINARY_AVAILABLE="true"
    else
        # A precompiled binary does not appear to be available for this device.
        echo -e "\e[94m  A precompiled PhantomJS binary does not appear to be available for this CPU's arcitecture...\e[97m"
        BINARY_AVAILABLE="false"

        if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
            # Warn the user of the build time if there is no binary available for download.
            # The user should be allowed to cancel out of the setup process at this time.
            whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "PhantomJS Binary Not Available" --yesno "It appears there is not a precompiled PhantomJS binary available for your devices architecture.\n\nThis script is capable of downloading and compiling the PhantomJS source but THIS MAY TAKE AN EXTREMELY LONG TO TO COMPLETE. Expect the build process to range anywhere from a half our to literally hours.\n\nDo you wish to compile PhantomJS from source?" 13 78
            if [[ $? -eq 1 ]] ; then
                # Setup has been halted by the user.
                echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
                echo "  Setup has been halted at the request of the user."
                echo ""
                echo -e "\e[93m----------------------------------------------------------------------------------------------------"
                echo -e "\e[92m  AboveTustin setup halted.\e[39m"
                echo ""
                read -p "Press enter to continue..." CONTINUE
                exit 1
            fi
        else
            # If the user elected to not compile the PhantomJS binary if needed in the installation configuration file exit now.
            if [[ ! ${ABOVETUSTIN_COMPILE_IF_NEEDED} = "true" ]] ; then
                echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
                echo "  A prebuilt PhantomJS binary is not available for this system."
                echo ""
                echo -e "\e[93m----------------------------------------------------------------------------------------------------"
                echo -e "\e[92m  AboveTustin setup halted.\e[39m"
                echo ""
                exit 1
            fi
        echo -e "\e[94m  Will attempt to build the PhantomJS binary from source...\e[97m"
        fi
    fi
fi

### GATHER TWITTER API INFORMATION FROM THE USER

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Twiter Keys and Tokens" --yesno "In order to send Tweets to Twitter using AboveTustin you will need to obtain the proper keys and tokens from Twitter. You will need to sign up for a Twitter developer account at https://apps.twitter.com and create an application there in order to obtain this information.\n\nMore information on obtaining Twitter keys and access tokens can be found in the projects wiki page.\n\nhttps://github.com/jprochazka/adsb-receiver/wiki/Setting-Up-AboveTustin\n\nProceed with the AboveTustin setup?" 20 78
    if [[ $? -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo ""
        echo -e "\e[93m----------------------------------------------------------------------------------------------------"
        echo -e "\e[92m  AboveTustin setup halted.\e[39m"
        echo ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

# If any exist assign the current Twitter keys and access tokens to variables.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    TWITTER_ACCESS_TOKEN_TITLE="Twitter Access Token"
    while [[ -z ${TWITTER_ACCESS_TOKEN} ]] ; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini ]] ; then
            TWITTER_ACCESS_TOKEN=`GetConfig "access_token" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"`
        fi
        TWITTER_ACCESS_TOKEN=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${TWITTER_ACCESS_TOKEN_TITLE}" --nocancel --inputbox "\nEnter your Twitter Access Token." 7 78 "${TWITTER_ACCESS_TOKEN}" 3>&1 1>&2 2>&3)
        TWITTER_ACCESS_TOKEN_TITLE="Twitter Access Token (REQUIRED)"
    done

    TWITTER_ACCESS_TOKEN_SECRET_TITLE="Twitter Access Token Secret"
    while [[ -z ${TWITTER_ACCESS_TOKEN_SECRET} ]] ; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini ]] ; then
            TWITTER_ACCESS_TOKEN_SECRET=`GetConfig "access_token_secret" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"`
        fi
        TWITTER_ACCESS_TOKEN_SECRET=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${TWITTER_ACCESS_TOKEN_SECRET_TITLE}" --nocancel --inputbox "\nEnter your Twitter Access Token Secret." 7 78 "${TWITTER_ACCESS_TOKEN_SECRET}" 3>&1 1>&2 2>&3)
        TWITTER_ACCESS_TOKEN_SECRET_TITLE="Twitter Access Token Secret (REQUIRED)"
    done

    TWITTER_CONSUMER_KEY_TITLE="Twitter Consumer Key"
    while [[ -z ${TWITTER_CONSUMER_KEY} ]] ; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini ]] ; then
            TWITTER_CONSUMER_KEY=`GetConfig "consumer_key" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"`
        fi
        TWITTER_CONSUMER_KEY=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${TWITTER_CONSUMER_KEY}_TITLE" --nocancel --inputbox "\nEnter your Twitter Consumer Key." 7 78 "${TWITTER_CONSUMER_KEY}" 3>&1 1>&2 2>&3)
        TWITTER_CONSUMER_KEY_TITLE="Twitter Consumer Key (REQUIRED)"
    done

    TWITTER_CONSUMER_SECRET_TITLE="Twitter Consumer Secret"
    while [[ -z ${TWITTER_CONSUMER_SECRET} ]] ; do
        if [[ -f ${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini ]] ; then
            TWITTER_CONSUMER_SECRET=`GetConfig "consumer_secret" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"`
        fi
        TWITTER_CONSUMER_SECRET=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "${TWITTER_CONSUMER_SECRET}_TITLE" --nocancel --inputbox "\nEnter your Twitter Consumer Secret." 7 78 "${TWITTER_CONSUMER_SECRET}" 3>&1 1>&2 2>&3)
        TWITTER_CONSUMER_SECRET_TITLE="Twitter Consumer Secret (REQUIRED)"
    done
fi

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo ""

# The package ttf-mscorefonts-installer requires contrib be added to the Debian repositories contained in /etc/apt/sources.list.
# The contrib flag does not need to be added for Raspbian Jessie and Ubuntu only Debian so far.
if [[ `lsb_release -si` = "Debian" ]] ; then
    echo -e "\e[94m  Adding the contrib component to the repositories contained sources.list...\e[97m"
    sudo sed -i 's/main/main contrib/g' /etc/apt/sources.list 2>&1
    echo -e "\e[94m  Updating the repository package lists...\e[97m"
    sudo apt-get update 2>&1
fi

CheckPackage ttf-mscorefonts-installer
CheckPackage python3-pip
CheckPackage libstdc++6
CheckPackage flex
CheckPackage bison
CheckPackage gperf
CheckPackage ruby
CheckPackage perl
CheckPackage libsqlite3-dev
CheckPackage libfontconfig1
CheckPackage libfontconfig1-dev
CheckPackage libicu-dev
CheckPackage libfreetype6
CheckPackage libssl-dev
CheckPackage libjpeg-dev
CheckPackage python
CheckPackage libx11-dev
CheckPackage libxext-dev
CheckPackage libpng12-dev
CheckPackage libc6
CheckPackage curl

if [[ "${BINARY_AVAILABLE}" = "false" ]] ; then
    # These packages are only needed if the user decided to build PhantomJS.
    CheckPackage build-essential
    CheckPackage g++
else
    # Package needed if the prebuilt PhantomJS binary is to be downloaded.
    CheckPackage bzip2
fi

### SETUP PHANTOMJS IF IT DOES NOT ALREADY EXIST ON THIS DEVICE

if [[ "${PHANTOMJS_EXISTS}" = "false" ]] ; then
    if [[ "${BINARY_AVAILABLE}" = "true" ]] ; then

        # DOWNLOAD THE PHANTOMJS BINARY

        echo ""
        echo -e "\e[95m  Downloading then placing the PhantomJS binary...\e[97m"
        echo ""

        # Enter the root of the project build directory.
        echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
        cd ${RECEIVER_BUILD_DIRECTORY} 2>&1

        # Download the proper PhantomJS binary.
        case ${CPU_ARCHITECTURE} in
            "armv7l")
                # Download the armv7l version of the PhantomJS binary from https://github.com/jprochazka/phantomjs-linux-armv7l.
                echo -e "\e[94m  Downloading the ${CPU_ARCHITECTURE} PhantomJS v${PHANTOMJS_VERSION} binary for Linux...\e[97m"
                echo ""
                curl -L "https://github.com/jprochazka/phantomjs-linux-armv7l/releases/download/2.1.1/phantomjs-2.1.1-linux-armv7l.tar.bz2" 2>&1
                ;;
            "x86_64")
                # Download the x86_64 version of the PhantomJS binary from the PhantomJS web site.
                echo -e "\e[94m  Downloading the official ${CPU_ARCHITECTURE} PhantomJS v${PHANTOMJS_VERSION} binary for Linux...\e[97m"
                echo ""
                curl -L "https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2" 2>&1
                ;;
            "i686")
                # Download the i686 version of the PantomJS binary from the PhantomJS web site.
                echo -e "\e[94m  Downloading the official ${CPU_ARCHITECTURE} PhantomJS v${PHANTOMJS_VERSION} binary for Linux...\e[97m"
                echo ""
                curl -L "https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-i686.tar.bz2" 2>&1
                ;;
        esac

        # Extract the files from the PhantomJS archive which was just downloaded.
        echo -e "\e[94m  Extracting the PhantomJS binary archive...\e[97m"
        echo ""
        tar -vxfj phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}.tar 2>&1
        rm -vf phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}.tar 2>&1

        # Move the binary into the /usr/bin directory and make it executable.
        echo -e "\e[94m  Copying the PhantomJS binary into the directory /usr/bin...\e[97m"
        sudo cp -v phantomjs-${PHANTOMJS_VERSION}-linux-${CPU_ARCHITECTURE}/bin/phantomjs /usr/bin 2>&1
        echo ""
        echo -e "\e[94m  Making the file /usr/bin/phantomjs executable...\e[97m"
        sudo chmod -v +x /usr/bin/phantomjs 2>&1
        echo ""

    else

        # BUILD PHANTOMJS

        echo ""
        echo -e "\e[95m  Building then placing the PhantomJS binary...\e[97m"
        echo ""

        # Download the source code.
        echo ""
        echo -e "\e[95m  Preparing the PhantomJS Git repository...\e[97m"
        echo ""
        if [[ -d ${RECEIVER_BUILD_DIRECTORY}/phantomjs ]] && [[ -d ${RECEIVER_BUILD_DIRECTORY}/phantomjs/.git ]] ; then
            # A directory with a git repository containing the source code already exists.
            echo -e "\e[94m  Entering the PhantomJS git repository directory...\e[97m"
            cd ${RECEIVER_BUILD_DIRECTORY}/phantomjs 2>&1
            echo -e "\e[94m  Updating the local PhantomJS git repository...\e[97m"
            echo ""
            git pull --all 2>&1
        else
            # A directory containing the source code does not exist in the build directory.
            echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
            cd ${RECEIVER_BUILD_DIRECTORY} 2>&1
            echo -e "\e[94m  Cloning the PhantomJS git repository locally...\e[97m"
            echo ""
            git clone git://github.com/ariya/phantomjs.git 2>&1
            echo ""
        fi

        # Enter the PhantomJS build directory if not already there.
        if [[ ! "${PWD}" = ${RECEIVER_BUILD_DIRECTORY}/phantomjs ]] ; then
            echo -e "\e[94m  Entering the PhantomJS Git repository directory...\e[97m"
            cd ${RECEIVER_BUILD_DIRECTORY}/phantomjs 2>&1
        fi

        # Checkout the proper branch then init and update the submodules.
        echo -e "\e[94m  Checking out the branch ${PHANTOMJS_VERSION}...\e[97m"
        echo ""
        git checkout ${PHANTOMJS_VERSION} 2>&1
        echo ""
        echo -e "\e[94m  Initializing Git submodules...\e[97m"
        echo ""
        git submodule init 2>&1
        echo ""
        echo -e "\e[94m  Updating Git submodules...\e[97m"
        echo ""
        git submodule update 2>&1
        echo ""

        # Compile and link the code.
        if [[ "${CPU_ARCHITECTURE}" = "armv7l" ]] || [[ "${CPU_ARCHITECTURE}" = "armv6l" ]] || [[ "${CPU_ARCHITECTURE}" = "aarch64" ]] ; then
            # Limit the amount of processors being used on Raspberry Pi devices.
            # Not doing will very likely cause the compile to fail due to an out of memory error.
            echo -e "\e[94m  Building PhantomJS... (Job will be limited to using 1 processor.)\e[97m"
            python build.py -j 1 2>&1
        else
            echo -e "\e[94m  Building PhantomJS...\e[97m"
            python build.py 2>&1
        fi
        echo ""

        # Test that the binary was built properly.
        if [[ ! -f "bin/pahntomjs" ]] || [[ ! "`bin/phantomjs --version`" -eq "${PHANTOMJS_VERSION}" ]] ; then
            # If the dump978 binaries could not be found halt setup.
            echo ""
            echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
            echo -e "  THE PHANTOMJS BINARIES BUILD APPEARS TO HAVE FAILED."
            echo -e "  SETUP HAS BEEN TERMINATED!"
            echo ""
            echo -e "\e[93mThe PhantomJS binary appear to have not been built successfully..\e[39m"
            echo ""
            echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
            echo -e "\e[92m  AboveTustin setup halted.\e[39m"
            echo ""
            read -p "Press enter to continue..." CONTINUE
            exit 1
        fi

        # Move the binary into the /usr/bin directory and make it executable.
        echo -e "\e[94m  Copying the PhantomJS binary into the directory /usr/bin...\e[97m"
        sudo cp -v bin/phantomjs /usr/bin 2>&1
        echo -e "\e[94m  Making the file /usr/bin/phantomjs executable...\e[97m"
        sudo chmod -v +x /usr/bin/phantomjs 2>&1

    fi
fi

### INSTALL THE NEEDED PYTHON MODULES

echo ""
echo -e "\e[95m  Setting up the required Python modules...\e[97m"
echo ""

# Upgrade pip.
echo -e "\e[94m  Upgrading pip...\e[97m"
echo ""
sudo pip3 install --upgrade pip 2>&1
echo ""
echo -e "\e[94m  Upgrading virtualenv...\e[97m"
echo ""
sudo pip3 install --upgrade virtualenv 2>&1
echo ""

# Install Python modules.
echo -e "\e[94m  Installing the selenium Python module...\e[97m"
echo ""
sudo pip3 install selenium 2>&1
echo ""
echo -e "\e[94m  Installing the twitter Python module...\e[97m"
echo ""
sudo pip3 install twitter 2>&1
echo ""
echo -e "\e[94m  Installing the python-dateutil Python module...\e[97m"
echo ""
sudo pip3 install python-dateutil 2>&1
echo ""

### SETUP ABOVETUSTIN

echo ""
echo -e "\e[95m  Downloading and configuring AboveTustin...\e[97m"
echo ""

echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
cd ${RECEIVER_BUILD_DIRECTORY} 2>&1

echo -e "\e[94m  Checking if the AboveTustin Git repository has been cloned...\e[97m"
if [[ -d ${RECEIVER_BUILD_DIRECTORY}/AboveTustin ]] && [[ -d ${RECEIVER_BUILD_DIRECTORY}/AboveTustin/.git ]] ; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the AboveTustin git repository directory...\e[97m"
    cd ${RECEIVER_BUILD_DIRECTORY}/AboveTustin 2>&1
    echo -e "\e[94m  Updating the local AboveTustin git repository...\e[97m"
    echo ""
    git pull 2>&1
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    mkdir -v -p ${RECEIVER_BUILD_DIRECTORY} 2>&1
    cd ${RECEIVER_BUILD_DIRECTORY} 2>&1
    echo -e "\e[94m  Cloning the AboveTustin git repository locally...\e[97m"
    echo ""
    git clone https://github.com/kevinabrandon/AboveTustin.git 2>&1
    echo ""
fi

# Copy the file config.sample.ini to config.ini
if [[ ! -f "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini" ]] ; then
    echo -e "\e[94m  Copying the file config.sample.ini to the file config.ini...\e[97m"
    cp -v ${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.sample.ini ${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini 2>&1
else
    echo -e "\e[94m  Found existing configuration file config.ini...\e[97m"
fi

# Establish timezone.
if [[ -z ${TIME_ZONE} ]] ; then
    echo -e "\e[94m  Establishing time zone...\e[97m"
    TIME_ZONE=`cat /etc/timezone`
fi

# Write out the supplied values to the file config.ini.
if [[ -n "${TWITTER_ACCESS_TOKEN}" ]] ; then
    echo -e "\e[94m  Writing the Twitter token value to the config.ini file...\e[97m"
    ChangeConfig "access_token" "${TWITTER_ACCESS_TOKEN}" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"
fi
if [[ -n "${TWITTER_ACCESS_TOKEN_SECRET}" ]] ; then
    echo -e "\e[94m  Writing the Twitter token secret value to the config.ini file...\e[97m"
    ChangeConfig "access_token_secret" "${TWITTER_ACCESS_TOKEN_SECRET}" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"
fi
if [[ -n "${TWITTER_CONSUMER_KEY}" ]] ; then
    echo -e "\e[94m  Writing the Twitter consumer key value to the config.ini file...\e[97m"
    ChangeConfig "consumer_key" "${TWITTER_CONSUMER_KEY}" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"
fi
if [[ -n "${TWITTER_CONSUMER_SECRET}" ]] ; then
    echo -e "\e[94m  Writing the Twitter consumer secret to the config.ini file...\e[97m"
    ChangeConfig "consumer_secret" "${TWITTER_CONSUMER_SECRET}" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"
fi
if [[ -n "${TIME_ZONE}" ]] ; then
    echo -e "\e[94m  Writing the receiver's timezone to the config.ini file...\e[97m"
    ChangeConfig "time_zone" "${TIME_ZONE}" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"
fi

# Ask for the receivers latitude and longitude.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Explain to the user that the receiver's latitude and longitude is required.
    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Receiver Latitude and Longitude" --msgbox "Your receivers latitude and longitude are required for distance calculations to work properly. You will now be asked to supply the latitude and longitude for your receiver. If you do not have this information you get it by using the web based \"Geocode by Address\" utility hosted on another of my websites.\n\n  https://www.swiftbyte.com/toolbox/geocode" 13 78
    # Ask the user for the receiver's latitude.
    RECEIVER_LATITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Receiver Latitude" --nocancel --inputbox "\nEnter your receiver's latitude.\n(Example: XX.XXXXXXX)" 9 78 3>&1 1>&2 2>&3)
    while [[ -z ${RECEIVER_LATITUDE} ]] ; do
        RECEIVER_LATITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Receiver Latitude (REQUIRED)" --nocancel --inputbox "\nEnter your receiver's latitude.\n(Example: XX.XXXXXXX)" 9 78 3>&1 1>&2 2>&3)
    done
    # Ask the user for the receiver's longitude.
    RECEIVER_LONGITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Receiver Longitude" --nocancel --inputbox "\nEnter your receeiver's longitude.\n(Example: XX.XXXXXXX)" 9 78 3>&1 1>&2 2>&3)
    while [[ -z ${RECEIVER_LONGITUDE} ]] ; do
        RECEIVER_LONGITUDE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Receiver Longitude (REQUIRED)" --nocancel --inputbox "\nEnter your receeiver's longitude.\n(Example: XX.XXXXXXX)" 9 78 3>&1 1>&2 2>&3)
    done
fi
echo -e "\e[94m  Writing the receiver's latitude to the config.ini file...\e[97m"
ChangeConfig "latitude" "${RECEIVER_LATITUDE}" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"
echo -e "\e[94m  Writing the receiver's longitude to the config.ini file...\e[97m"
ChangeConfig "longitude" "${RECEIVER_LONGITUDE}" "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/config.ini"

# Add the run_tracker.sh script to /etc/rc.local so it is executed at boot up.
echo -e "\e[94m  Checking if the AboveTustin startup line is contained within the file /etc/rc.local...\e[97m"
if [[ ! grep -Fxq "${RECEIVER_BUILD_DIRECTORY}/AboveTustin/run_tracker.sh &" /etc/rc.local ]] ; then
    echo -e "\e[94m  Adding the AboveTustin startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i ${RECEIVER_BUILD_DIRECTORY}/AboveTustin/run_tracker.sh &\n" /etc/rc.local
fi

# Kill any currently running instances of run_tracker.sh, tracker.py or phantomjs.
PROCS="run_tracker.sh tracker.py phantomjs"
for PROC in ${PROCS} ; do
    echo -e "\e[94m  Checking for any running ${PROC} processes...\e[97m"
    PIDS=`ps -efww | grep -w "${PROC} " | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [[ ! -z "${PIDS}" ]] ; then
        echo -e "\e[94m  Killing any running ${PROC} processes...\e[97m"
        sudo kill ${PIDS} 2>&1
        sudo kill -9 ${PIDS} 2>&1
    fi
    unset PIDS
done

# Start the run_tracker.sh script
echo -e "\e[94m  Executing the run_tracker.sh script...\e[97m"
sudo nohup ${RECEIVER_BUILD_DIRECTORY}/AboveTustin/run_tracker.sh > /dev/null 2>&1 &

### ABOVETUSTIN SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo ""
echo -e "\e[93m----------------------------------------------------------------------------------------------------"
echo -e "\e[92m  AboveTustin setup is complete.\e[39m"
echo ""
if [[ ${RECEIVER_AUTOMATED_INSTALL} = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0
