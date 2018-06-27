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
# Copyright (c) 2015-2018, Joseph A. Prochazka                                      #
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

RECEIVER_ROOT_DIRECTORY="${PWD}"
RECEIVER_BASH_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/bash"
RECEIVER_BUILD_DIRECTORY="${RECEIVER_ROOT_DIRECTORY}/build"

### INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh

## SET INSTALLATION VARIABLES

# Source the automated install configuration file if this is an automated installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "true" ]] && [[ -s "${RECEIVER_CONFIGURATION_FILE}" ]] ; then
    source ${RECEIVER_CONFIGURATION_FILE}
fi

### BEGIN SETUP

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    clear
    echo -e "\n\e[91m   ${RECEIVER_PROJECT_TITLE}"
fi
echo -e ""
echo -e "\e[92m  Setting up ADSBHub feeder client..."
echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------\e[96m"
echo -e ""

# Confirm component installation.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    # Interactive install.
    CONTINUE_SETUP=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADSBHub client Setup" --yesno "There are many Web sites tracking aircraft and all of them rely on data shared by ADS-B fans. However, the access to aggregated ADS-B worldwide data is limited. The main goal of ADSBHub is to become a ADS-B data sharing centre and valuable data source for all enthusiasts and professionals interested in development of ADS-B related software. For more information please see their website:\n\n  http://www.adsbhub.org/howtofeed.php\n\nContinue setup by installing the ADSBHub client?" 13 78 3>&1 1>&2 2>&3)
    if [[ ${CONTINUE_SETUP} -eq 1 ]] ; then
        # Setup has been halted by the user.
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        echo -e "\e[93m  ------------------------------------------------------------------------------"
        echo -e "\e[92m  ADSBHub client setup halted.\e[39m"
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
else
    # Warn that automated installation is not supported.
    echo -e "\e[92m  Automated installation of this script is not yet supported...\e[39m"
    echo -e ""
    exit 1
fi

### INSTALL REQUIRED PACKAGES IF THEY ARE NOT ALREADY INSTALLED

CheckPackage wget
CheckPackage netcat

### ENABLE THE USE OF /ETC/RC.LOCAL IF THE FILE DOES NOT EXIST

if [ ! -f /etc/rc.local ]; then
    echo ""
    echo -e "\e[95m  Enabling the use of the /etc/rc.local file...\e[97m"
    echo ""

    # In Debian Stretch /etc/rc.local has been removed.
    # However at this time we can bring this file back into play.
    # As to if in future releases this will work remains to be seen...

    echo -e "\e[94m  Creating the file /etc/rc.local...\e[97m"
    sudo tee /etc/rc.local > /dev/null <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
exit 0
EOF

    echo -e "\e[94m  Making /etc/rc.local executable...\e[97m"
    sudo chmod +x /etc/rc.local
    echo -e "\e[94m  Enabling the use of /etc/rc.local...\e[97m"
    sudo systemctl start rc-local
fi

### DOWNLOAD AND SETUP THE ADSBHUB CLIENT SCRIPT

echo ""
echo -e "\e[95m  Setting up the ADSBHub client...\e[97m"
echo ""

# Create the adsbexchange directory in the build directory if it does not exist.
echo -e "\e[94m  Checking for the ADSBHub build directory...\e[97m"
if [ ! -d "$RECEIVER_BUILD_DIRECTORY/adsbhub" ]; then
    echo -e "\e[94m  Creating the ADSBHub build directory...\e[97m"
    mkdir $RECEIVER_BUILD_DIRECTORY/adsbhub
fi

# Download the ADSBHub script.
echo -e "\e[94m  Downloading the ADSBHub client...\e[97m"
echo -e ""
wget http://www.adsbhub.org/downloads/adsbhub.sh -O ${RECEIVER_BUILD_DIRECTORY}/adsbhub/adsbhub.sh
echo ""
echo -e "\e[94m  Setting execute permissions on $RECEIVER_BUILD_DIRECTORY/adsbhub/adsbhub.sh...\e[97m"
chmod +x $RECEIVER_BUILD_DIRECTORY/adsbhub/adsbhub.sh

### ADD STARTUP LINE TO /ETC/RC.LOCAL

echo -e "\e[94m  Checking if the ADSBHub startup line is contained within the file /etc/rc.local...\e[97m"
if ! grep -Fxq "$RECEIVER_BUILD_DIRECTORY/adsbhub/adsbhub.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the ADSBHub startup script line to the file /etc/rc.local...\e[97m"
    lnum=($(sed -n '/exit 0/=' /etc/rc.local))
    ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i $RECEIVER_BUILD_DIRECTORY/adsbhub/adsbhub.sh &\n" /etc/rc.local
fi

### START THE ADSBHUB CLIENT

echo ""
echo -e "\e[95m  Starting the ADSBHub client...\e[97m"
echo ""

# Kill any currently running instances of the adsbexchange-socat_maint.sh script.
echo -e "\e[94m  Checking for any running adsbexchange-socat_maint.sh processes...\e[97m"
if [[ $(ps -aux | grep '[a]dsbhub.sh' | awk '{print $2}') ]]; then
    echo -e "\e[94m  Killing the current adsbhub.sh process...\e[97m"
    sudo kill -9 $(ps -aux | grep '[a]dsbhub.sh' | awk '{print $2}') &> /dev/null
fi

echo -e "\e[94m  Executing the ADSBHub client script...\e[97m"
sudo nohup $RECEIVER_BUILD_DIRECTORY/adsbhub/adsbhub.sh > /dev/null 2>&1 &

### INFORM THE USER THERE IS MORE TO DO

whiptail --title "Complete Setup at ADSBHub.org" --msgbox "IMPORTANT!!!\n\nIn order to complete the ADSBHub setup process you will need to create/login to your ADSBHub account at http://www.adsbhub.com. After logining into your account click on the \"Settings\" button then next to your \"Profile\" tab click on \"New Station\" and fill out the form." 12 78

### SETUP COMPLETE

# Return to the project root directory.
echo -e "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
cd ${RECEIVER_ROOT_DIRECTORY} 2>&1

echo -e ""
echo -e "\e[93m  ------------------------------------------------------------------------------"
echo -e "\e[92m  OpenSky Network feeder client setup is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0
