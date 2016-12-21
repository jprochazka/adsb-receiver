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

### VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
PHANTOMJSBUILDDIRECTORY="$BUILDDIRECTORY/phantomjs"

### INCLUDE EXTERNAL SCRIPTS

source $BASHDIRECTORY/variables.sh
source $BASHDIRECTORY/functions.sh

### BEGIN SETUP

clear
echo -e "\n\e[91m  $ADSB_PROJECTTITLE"
echo -e ""
echo -e "\e[92m  Setting up AboveTustin..."
echo -e "\e[93m----------------------------------------------------------------------------------------------------\e[96m"
echo -e ""
whiptail --backtitle "$ADSB_PROJECTTITLE" --title "AboveTustin Setup" --yesno "AboveTustin is an ADS-B Twitter Bot. Uses dump1090-mutability to track airplanes and then tweets whenever an airplane flies overhead.\n\n  https://github.com/kevinabrandon/AboveTustin\n\nContinue setting up AboveTustin?" 13 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  AboveTustin setup halted.\e[39m"
    echo -e ""
    if [[ ! -z ${VERBOSE} ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

### CHECK IF A PHANTOMJS ALREADY EXISTS OR IF A PRECOMPILED BINARY IS AVAILABLE FOR THIS DEVICE

echo -e "\e[95m  Checking for PhantomJS...\e[97m"
echo -e ""
if [ -f /usr/bin/phantomjs ] && [ `phantomjs --version` = $PHANTOMJSVERSION ]; then
    # A PhantomJS binary which is the proper version appears to exist on this device.
    echo -e "\e[94m  PhantomJS is present on this device and is the proper version...\e[97m"
    PHANTOMJSEXISTS="true"
else
    echo -e "\e[91m  PhantomJS is not present on this device or is not the proper version...\e[97m"
    PHANTOMJSEXISTS="false"
    echo -e "\e[94m  Checking if a precompiled PhantomJS binary is available for download...\e[97m"
    echo -e "\e[94m  Detecting CPU architeture...\e[97m"
    CPUARCHITECTURE=`uname -m`
    echo -e "\e[94m  CPU architecture detected as $CPUARCHITECTURE...\e[97m"
    if [ $CPUARCHITECTURE = "x86_64" ] || or [  $CPUARCHITECTURE = "i686" ]; then
        # A precompiled binary should be available for this device.
        echo -e "\e[94m  A precompiled PhantomJS binary appears to be available for this CPU's arcitecture...\e[97m"
        BINARYAVAILABLE="true"
    else
        # A precompiled binary does not appear to be available for this device.
        echo -e "\e[94m  A precompiled PhantomJS binary does not appear to be available for this CPU's arcitecture...\e[97m"
        BINARYAVAILABLE="false"
        # Warn the user of the build time if there is no binary available for download.
        # The user should be allowed to cancel out of the setup process at this time.
        whiptail --backtitle "$ADSB_PROJECTTITLE" --title "PhantomJS Binary Not Available" --yesno "It appears there is not a precompiled PhantomJS binary available for your devices architecture.\n\nThis script is capable of downloading and compiling the PhantomJS source but THIS MAY TAKE AN EXTREMELY LONG TO TO COMPLETE. Expect the build process to range anywhere from a half our to literally hours.\n\nDo you wish to compile PhantomJS from source?" 13 78
        CONTINUESETUP=$?
        if [ $CONTINUESETUP = 1 ]; then
            # Setup has been halted by the user.
            echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
            echo -e "  Setup has been halted at the request of the user."
            echo -e ""
            echo -e "\e[93m----------------------------------------------------------------------------------------------------"
            echo -e "\e[92m  AboveTustin setup halted.\e[39m"
            echo -e ""
            if [[ ! -z ${VERBOSE} ]] ; then
                read -p "Press enter to continue..." CONTINUE
            fi
            exit 1
        fi
        echo -e "\e[94m  Will attempt to build the PhantomJS binary from source...\e[97m"
    fi
fi

### GATHER TWITTER API INFORMATION FROM THE USER

whiptail --backtitle "$ADSB_PROJECTTITLE" --title "Twiter Keys and Tokens" --yesno "In order to send Tweets to Twitter using AboveTustin you will need to obtain the proper keys and tokens from Twitter. You will need to sign up for a Twitter developer account at https://apps.twitter.com and create an application there in order to obtain this information.\n\nMore information on obtaining Twitter keys and access tokens can be found in the projects wiki page.\n\nhttps://github.com/jprochazka/adsb-receiver/wiki/Setting-Up-AboveTustin\n\nProceed with the AboveTustin setup?" 20 78
CONTINUESETUP=$?
if [ $CONTINUESETUP = 1 ]; then
    # Setup has been halted by the user.
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m----------------------------------------------------------------------------------------------------"
    echo -e "\e[92m  AboveTustin setup halted.\e[39m"
    echo -e ""
    if [[ ! -z ${VERBOSE} ]] ; then
        read -p "Press enter to continue..." CONTINUE
    fi
    exit 1
fi

# If any exist assign the current Twitter keys and access tokens to variables.

TWITTERACCESSTOKEN_TITLE="Twitter Access Token"
while [[ -z $TWITTERACCESSTOKEN ]]; do
    TWITTERACCESSTOKEN=""
    if [ -f $BUILDDIRECTORY/AboveTustin/keys/token ]; then
        TWITTERACCESSTOKEN=`cat $BUILDDIRECTORY/AboveTustin/keys/token`
    fi
    TWITTERACCESSTOKEN=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$TWITTERACCESSTOKEN_TITLE" --nocancel --inputbox "\nEnter your Twitter Access Token." 7 78 "$TWITTERACCESSTOKEN" 3>&1 1>&2 2>&3)
    TWITTERACCESSTOKEN_TITLE="Twitter Access Token (REQUIRED)"
done
TWITTERACCESSTOKENSECRET_TITLE="Twitter Access Token Secret"
while [[ -z $TWITTERACCESSTOKENSECRET ]]; do
    TWITTERACCESSTOKENSECRET=""
    if [ -f $BUILDDIRECTORY/AboveTustin/keys/token_secret ]; then
        TWITTERACCESSTOKENSECRET=`cat $BUILDDIRECTORY/AboveTustin/keys/token_secret`
    fi
    TWITTERACCESSTOKENSECRET=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$TWITTERACCESSTOKENSECRET_TITLE" --nocancel --inputbox "\nEnter your Twitter Access Token Secret." 7 " $TWITTERACCESSTOKENSECRET"78 3>&1 1>&2 2>&3)
    TWITTERACCESSTOKENSECRET_TITLE="Twitter Access Token Secret (REQUIRED)"
done
TWITTERCONSUMERKEY_TITLE="Twitter Consumer Key"
while [[ -z $TWITTERCONSUMERKEY ]]; do
    TWITTERCONSUMERKEY=""
    if [ -f $BUILDDIRECTORY/AboveTustin/keys/consumer_key ]; then
        TWITTERCONSUMERKEY=`cat $BUILDDIRECTORY/AboveTustin/keys/consumer_key`
    fi
    TWITTERCONSUMERKEY=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$TWITTERCONSUMERKEY_TITLE" --nocancel --inputbox "\nEnter your Twitter Consumer Key." 7 78 "TWITTERCONSUMERKEY" 3>&1 1>&2 2>&3)
    TWITTERCONSUMERKEY_TITLE="Twitter Consumer Key (REQUIRED)"
done
TWITTERCONSUMERSECRET_TITLE="Twitter Consumer Secret"
while [[ -z $TWITTERCONSUMERSECRET ]]; do
    TWITTERCONSUMERSECRET=""
    if [ -f $BUILDDIRECTORY/AboveTustin/keys/consumer_secret ]; then
        TWITTERCONSUMERSECRET=`cat $BUILDDIRECTORY/AboveTustin/keys/consumer_secret`
    fi
    TWITTERCONSUMERSECRET=$(whiptail --backtitle "$ADSB_PROJECTTITLE" --title "$TWITTERCONSUMERSECRET_TITLE" --nocancel --inputbox "\nEnter your Twitter Consumer Secret." 7 78 "$TWITTERCONSUMERSECRET" 3>&1 1>&2 2>&3)
    TWITTERCONSUMERSECRET_TITLE="Twitter Consumer Secret (REQUIRED)"
done

### CHECK FOR PREREQUISITE PACKAGES

echo -e "\e[95m  Installing packages needed to build and fulfill dependencies...\e[97m"
echo -e ""

# The package ttf-mscorefonts-installer requires contrib be added to the Debian repositories contained in /etc/apt/sources.list.
# The contrib flag does not need to be added for Raspbian Jessie and Ubuntu only Debian so far.
if [ `lsb_release -si` = "Debian" ]; then
    echo -e "\e[94m  Adding the contrib component to the repositories contained sources.list...\e[97m"
    sudo sed -i 's/main/main contrib/g' /etc/apt/sources.list
    echo -e "\e[94m  Updating the repository package lists...\e[97m"
    sudo apt-get update
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

if [ $BINARYAVAILABLE = "false" ]; then
    # These packages are only needed if the user decided to build PhantomJS.
    CheckPackage build-essential
    CheckPackage g++
else
    # Package needed if the prebuilt PhantomJS binary is to be downloaded.
    CheckPackage bzip2
fi

### SETUP PHANTOMJS IF IT DOES NOT ALREADY EXIST ON THIS DEVICE

if [ $PHANTOMJSEXISTS = "false" ]; then
    if [ $BINARYAVAILABLE = "true" ]; then

        # DOWNLOAD THE PHANTOMJS BINARY

        echo -e ""
        echo -e "\e[95m  Downloading then placing the PhantomJS binary...\e[97m"
        echo -e ""

        # Enter the root of the project build directory.
        echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
        cd $BUILDDIRECTORY

        # Download the proper PhantomJS binary.
        case $CPUARCHITECTURE in
            "x86_64")
                # Download the x86_64 version of the PhantomJS binary.
                echo -e "\e[94m  Downloading the official x86_64 PhantomJS v$PHANTOMJSVERSION binary for Linux...\e[97m"
                echo -e ""
                wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2
                ;;
            "i686"
                # Download the i686 version of the PantomJS binary.
                echo -e "\e[94m  Downloading the official i686 PhantomJS v$PHANTOMJSVERSION binary for Linux...\e[97m"
                echo -e ""
                wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-i686.tar.bz2
                ;;
        esac

        echo -e "\e[94m  Extracting the PhantomJS binary archive...\e[97m"
        echo -e ""
        bunzip2 -v phantomjs-${PHANTOMJSVERSION}-linux-$PHANTOMJSVERSION.tar.bz2
        tar -vxf phantomjs-${PHANTOMJSVERSION}-linux-$PHANTOMJSVERSION.tar
        rm -f phantomjs-${PHANTOMJSVERSION}-linux-$PHANTOMJSVERSION.tar

        # Move the binary into the /usr/bin directory and make it executable.
        echo -e "\e[94m  Copying the PhantomJS binary into the directory /usr/bin...\e[97m"
        sudo cp phantomjs-${PHANTOMJSVERSION}-linux-$PHANTOMJSVERSION/bin/phantomjs /usr/bin
        echo -e "\e[94m  Making the file /usr/bin/phantomjs executable...\e[97m"
        sudo chmod +x /usr/bin/phantomjs

    else

        # BUILD PHANTOMJS

        echo -e ""
        echo -e "\e[95m  Building then placing the PhantomJS binary...\e[97m"
        echo -e ""

        # Download the source code.
        echo -e ""
        echo -e "\e[95m  Preparing the PhantomJS Git repository...\e[97m"
        echo -e ""
        if [ -d $PHANTOMJSBUILDDIRECTORY ] && [ -d $PHANTOMJSBUILDDIRECTORY/.git ]; then
            # A directory with a git repository containing the source code already exists.
            echo -e "\e[94m  Entering the PhantomJS git repository directory...\e[97m"
            cd $PHANTOMJSBUILDDIRECTORY
            echo -e "\e[94m  Updating the local PhantomJS git repository...\e[97m"
            echo -e ""
            git pull --all
        else
            # A directory containing the source code does not exist in the build directory.
            echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
            cd $BUILDDIRECTORY
            echo -e "\e[94m  Cloning the PhantomJS git repository locally...\e[97m"
            echo -e ""
            git clone git://github.com/ariya/phantomjs.git
            echo -e ""
        fi

        # Enter the PhantomJS build directory if not already there.
        if [ ! $PWD = $PHANTOMJSBUILDDIRECTORY ]; then
            echo -e "\e[94m  Entering the PhantomJS Git repository directory...\e[97m"
            cd $PHANTOMJSBUILDDIRECTORY
        fi

        # Checkout the proper branch then init and update the submodules.
        echo -e "\e[94m  Checking out the branch $PHANTOMJSVERSION...\e[97m"
        echo -e ""
        git checkout $PHANTOMJSVERSION
        echo -e ""
        echo -e "\e[94m  Initializing Git submodules...\e[97m"
        echo -e ""
        git submodule init
        echo -e ""
        echo -e "\e[94m  Updating Git submodules...\e[97m"
        echo -e ""
        git submodule update
        echo -e ""

        # Compile and link the code.
        if [[ `uname -m` == "armv7l" ]] || [[ `uname -m` == "armv6l" ]] || [[ `uname -m` == "aarch64" ]]; then
            # Limit the amount of processors being used on Raspberry Pi devices.
            # Not doing will very likely cause the compile to fail due to an out of memory error.
            echo -e "\e[94m  Building PhantomJS... (Job will be limited to using 1 processor.)\e[97m"
            python build.py -j 1
        else
            echo -e "\e[94m  Building PhantomJS...\e[97m"
            python build.py
        fi
        echo -e ""

        # Test that the binary was built properly.
        if [ ! -f bin/pahntomjs ] || [ ! `bin/phantomjs --version` = $PHANTOMJSVERSION ]; then
            # If the dump978 binaries could not be found halt setup.
            echo -e ""
            echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
            echo -e "  THE PHANTOMJS BINARIES BUILD APPEARS TO HAVE FAILED."
            echo -e "  SETUP HAS BEEN TERMINATED!"
            echo -e ""
            echo -e "\e[93mThe PhantomJS binary appear to have not been built successfully..\e[39m"
            echo -e ""
            echo -e "\e[93m-------------------------------------------------------------------------------------------------------"
            echo -e "\e[92m  AboveTustin setup halted.\e[39m"
            echo -e ""
            if [[ ! -z ${VERBOSE} ]] ; then
                read -p "Press enter to continue..." CONTINUE
            fi
            exit 1
        fi

        # Move the binary into the /usr/bin directory and make it executable.
        echo -e "\e[94m  Copying the PhantomJS binary into the directory /usr/bin...\e[97m"
        sudo cp bin/phantomjs /usr/bin
        echo -e "\e[94m  Making the file /usr/bin/phantomjs executable...\e[97m"
        sudo chmod +x /usr/bin/phantomjs

    fi
fi

### INSTALL THE NEEDED PYTHON MODULES

echo -e ""
echo -e "\e[95m  Setting up the required Python modules...\e[97m"
echo -e ""

# Upgrade pip.
echo -e "\e[94m  Upgrading pip...\e[97m"
echo -e ""
sudo pip3 install --upgrade pip
echo -e ""
echo -e "\e[94m  Upgrading virtualenv...\e[97m"
echo -e ""
sudo pip3 install --upgrade virtualenv
echo -e ""

# Install Python modules.
echo -e "\e[94m  Installing the selenium Python module...\e[97m"
echo -e ""
sudo pip3 install selenium
echo -e ""
echo -e "\e[94m  Installing the twitter Python module...\e[97m"
echo -e ""
sudo pip3 install twitter
echo -e ""
echo -e "\e[94m  Installing the python-dateutil Python module...\e[97m"
echo -e ""
sudo pip3 install python-dateutil
echo -e ""

### SETUP ABOVETUSTIN

echo -e ""
echo -e "\e[95m  Downloading and configuring AboveTustin...\e[97m"
echo -e ""

echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
cd $BUILDDIRECTORY

echo -e "\e[94m  Checking if the AboveTustin Git repository has been cloned...\e[97m"
if [ -d $BUILDDIRECTORY/AboveTustin ] && [ -d $BUILDDIRECTORY/AboveTustin/.git ]; then
    # A directory with a git repository containing the source code already exists.
    echo -e "\e[94m  Entering the AboveTustin git repository directory...\e[97m"
    cd $BUILDDIRECTORY/AboveTustin
    echo -e "\e[94m  Updating the local AboveTustin git repository...\e[97m"
    echo -e ""
    git pull
else
    # A directory containing the source code does not exist in the build directory.
    echo -e "\e[94m  Entering the ADS-B Receiver Project build directory...\e[97m"
    mkdir -p $BUILDDIRECTORY
    cd $BUILDDIRECTORY
    echo -e "\e[94m  Cloning the AboveTustin git repository locally...\e[97m"
    echo -e ""
    git clone https://github.com/kevinabrandon/AboveTustin.git
    echo -e ""
fi

# Make the logs directory if it does not already exist.
cho -e "Checking if the directory $BUILDDIRECTORY/AboveTustin/logs exists...\e[97m"
if [ ! -d $BUILDDIRECTORY/AboveTustin/logs ]; then
    echo -e "\e[94m  Creating the directory $BUILDDIRECTORY/AboveTustin/logs...\e[97m"
    mkdir $BUILDDIRECTORY/AboveTustin/logs
fi

# Make the key directory if it does not already exist.
echo -e "Checking if the directory $BUILDDIRECTORY/AboveTustin/keys exists...\e[97m"
if [ ! -d $BUILDDIRECTORY/AboveTustin/keys ]; then
    echo -e "\e[94m  Creating the directory $BUILDDIRECTORY/AboveTustin/keys...\e[97m"
    mkdir $BUILDDIRECTORY/AboveTustin/keys
fi

# Write out the files which will contain the user's Twitter keys and access tokens.
echo -e "\e[94m  Adding the supplied token to the Twitter Token file...\e[97m"
echo "$TWITTERACCESSTOKEN" > $BUILDDIRECTORY/AboveTustin/keys/token
echo -e "\e[94m  Adding the supplied token secret to the Twitter Token Secret file...\e[97m"
echo "$TWITTERACCESSTOKENSECRET" > $BUILDDIRECTORY/AboveTustin/keys/token_secret
echo -e "\e[94m  Adding the supplied consumer key to the Twitter Consumer Key file...\e[97m"
echo "$TWITTERCONSUMERKEY" > $BUILDDIRECTORY/AboveTustin/keys/consumer_key
echo -e "\e[94m  Adding the supplied consumer secret to the Twitter Consumer Secret file...\e[97m"
echo "$TWITTERCONSUMERSECRET" > $BUILDDIRECTORY/AboveTustin/keys/consumer_secret

# Add the run_tracker.sh script to /etc/rc.local so it is executed at boot up.
echo -e "\e[94m  Checking if the AboveTustin startup line is contained within the file /etc/rc.local...\e[97m"
if ! grep -Fxq "$BUILDDIRECTORY/AboveTustin/run_tracker.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the AboveTustin startup line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i $BUILDDIRECTORY/AboveTustin/run_tracker.sh &\n" /etc/rc.local
fi

# Kill any currently running instances of the run_tracker.sh script.
echo -e "\e[94m  Checking for any running run_tracker.sh processes...\e[97m"
PIDS=`ps -efww | grep -w "run_tracker.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [ ! -z "$PIDS" ]; then
    echo -e "\e[94m  Killing any running run_tracker.sh processes...\e[97m"
    sudo kill $PIDS
    sudo kill -9 $PIDS
fi

echo -e "\e[94m  Checking for any running tracker.py processes...\e[97m"
PIDS=`ps -efww | grep -w "tracker.py" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [ ! -z "$PIDS" ]; then
    echo -e "\e[94m  Killing any running tracker.py processes...\e[97m"
    sudo kill $PIDS
    sudo kill -9 $PIDS
fi

echo -e "\e[94m  Checking for any running phantomjs processes...\e[97m"
PIDS=`ps -efww | grep -w "phantomjs" | awk -vpid=$$ '$2 != pid { print $2 }'`
if [ ! -z "$PIDS" ]; then
    echo -e "\e[94m  Killing any running phantomjs processes...\e[97m"
    sudo kill $PIDS
    sudo kill -9 $PIDS
fi

echo -e "\e[94m  Executing the adsbexchange-netcat_maint.sh script...\e[97m"
sudo nohup $BUILDDIRECTORY/AboveTustin/run_tracker.sh > /dev/null 2>&1 &

### ABOVETUSTIN SETUP COMPLETE

# Enter into the project root directory.
echo -e "\e[94m  Entering the ADS-B Receiver Project root directory...\e[97m"
cd $PROJECTROOTDIRECTORY

echo -e ""
echo -e "\e[93m----------------------------------------------------------------------------------------------------"
echo -e "\e[92m  AboveTustin setup is complete.\e[39m"
echo -e ""
if [[ ! -z ${VERBOSE} ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0
