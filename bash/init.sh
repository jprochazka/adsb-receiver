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

## CHECK IF THIS IS THE FIRST RUN USING THE IMAGE RELEASE

if [[ -f "${RECEIVER_ROOT_DIRECTORY}/image" ]] ; then
    # Execute image setup script.
    chmod +x ${RECEIVER_BASH_DIRECTORY}/image.sh
    ${RECEIVER_BASH_DIRECTORY}/image.sh
    if [[ $? -ne 0 ]] ; then
        echo -e ""
        echo -e "  \e[91m  IMAGE SETUP HAS BEEN TERMINISTED.\e[39m"
        echo -e ""
        exit 1
    fi
    exit 0
fi

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/functions.sh

## SET VARIABLES

TITLE="\e[1mThe ADS-B Receiver Project Preliminary Setup Process\e[0m"

## FUNCTIONS

# Update repository package lists.
function AptUpdate() {
    clear
    echo -e "\n\e[91m  ${TITLE}"
    echo -e ""
    echo -e "\e[92m  Downloading the latest package lists for all enabled repositories and PPAs..."
    echo -e "\e[93m  ------------------------------------------------------------------------------\e[97m"
    echo -e ""
    sudo apt-get update
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  Finished downloading and updating package lists.\e[39m"
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
    fi
}

# Check that the packages required by these scripts are installed.
function CheckPrerequisites() {
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        clear
        echo -e "\n\e[91m  ${TITLE}"
    fi
    echo -e ""
    echo -e "\e[92m  Checking to make sure the whiptail and git packages are installed..."
    echo -e "\e[93m  ------------------------------------------------------------------------------\e[97m"
    echo -e ""
    CheckPackage whiptail
    CheckPackage git
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  The whiptail and git packages are installed.\e[39m"
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
    fi
}

# Update The ADS-B Receiver Project Git repository.
function UpdateRepository() {
    # Update lcoal branches which are set to track remote.
    ACTION=$(git remote update 2>&1)
    # Check if local branch is behind remote.
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] && [[ `git status | grep -c "untracked files present"` -gt 0 ]] ; then
        # Local branch has untracked files.
        clear
        # Ask if the user wishes to save any changes made to any core files before resetting them.
        whiptail --backtitle "${TITLE}" --title "Backup Current ${RECEIVER_PROJECT_BRANCH} Branch State" --defaultno --yesno "This script will now reset your local copy of the ${RECEIVER_PROJECT_BRANCH} branch. Once this has been done any changes to the files making up this project will be replaced by untouched files from the project's repository.\n\nIf you would like to retain a copy of your current branch's state this script can do so now by migrating it to a new branch.\n\nCreate a new branch containing this branch's current state?" 14 78
        case $? in
            0) BACKUP_BRANCH_STATE="true" ;;
            1) BACKUP_BRANCH_STATE="false" ;;
        esac

        if [[ "${BACKUP_BRANCH_STATE}" = "true" ]] ; then
            # If the user wishes to create a new branch containing the current branches state ask for a name for this new branch.
            BACKUP_BRANCH_NAME_TITLE="Name Of Backup Branch"
            while [[ -z "${BACKUP_BRANCH_NAME}" ]] ; do
                BACKUP_BRANCH_NAME=$(whiptail --backtitle "${TITLE}" --title "${BACKUP_BRANCH_NAME_TITLE}" --nocancel --inputbox "\nPlease enter a name for this new branch." 10 78 3>&1 1>&2 2>&3)
                BACKUP_BRANCH_NAME_TITLE="Name Of Backup Branch (REQUIRED)"
            done
        fi
    fi

    echo -e "\n\e[91m  ${TITLE}"
    echo -e ""
    echo -e "\e[92m  Pulling the latest version of the ADS-B Receiver Project repository..."
    echo -e "\e[93m  ------------------------------------------------------------------------------\e[97m"
    echo -e ""
    echo -e "\e[94m  Switching to branch ${RECEIVER_PROJECT_BRANCH}...\e[97m"
    echo -e ""
    git checkout ${RECEIVER_PROJECT_BRANCH}
    echo -e ""

    # Save the current branch state if the user wished to do so.
    if [[ "${BACKUP_BRANCH_STATE}" = "true" ]] ; then
        echo -e "\e[94m  Creating a new branch named ${NEW_BRANCH_NAME} containing the current state of the ${RECEIVER_PROJECT_BRANCH} branch...\e[97m"
        echo -e ""
        git commit -a -m "Saving current branch state."
        git branch ${BACKUP_BRANCH_NAME}
        echo -e ""
    fi

    echo -e "\e[94m  Fetching branch ${RECEIVER_PROJECT_BRANCH} from origin...\e[97m"
    echo -e ""
    git fetch origin
    echo -e ""
    echo -e "\e[94m  Performing hard reset of branch ${RECEIVER_PROJECT_BRANCH} so it matches origin/${RECEIVER_PROJECT_BRANCH}...\e[97m"
    echo -e ""
    git reset --hard origin/${RECEIVER_PROJECT_BRANCH}
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  Finished pulling the latest version of the ADS-B Receiver Project repository....\e[39m"
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
    fi
}

# Update the operating system.
function UpdateOperatingSystem() {
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        clear
        echo -e "\n\e[91m  ${TITLE}"
    fi
    echo -e ""
    echo -e "\e[92m  Downloading and installing the latest updates for your operating system..."
    echo -e "\e[93m  ------------------------------------------------------------------------------\e[97m"
    echo -e ""
    sudo apt-get -y dist-upgrade
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  Your operating system should now be up to date.\e[39m"
    if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
    fi
}

## Update the repository packages and check that prerequisite packages are installed.

# Only call AptUpdate if last update was more than ${APT_UPDATE_THRESHOLD} seconds ago.
APT_UPDATE_THRESHOLD="1800"
APT_UPDATE_CURRENT_EPOCH=`date +%s`
APT_UPDATE_LAST_EPOCH=`stat -c %Y /var/cache/apt/pkgcache.bin`
APT_UPDATE_DELTA=`echo $[${APT_UPDATE_CURRENT_EPOCH} - ${APT_UPDATE_LAST_EPOCH}]`
if [[ "${APT_UPDATE_DELTA}" -gt "${APT_UPDATE_THRESHOLD}" ]] ; then
    AptUpdate
fi

CheckPrerequisites

## DISPLAY WELCOME SCREEN

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "The ADS-B Receiver Project" --title "The ADS-B Receiver Project" --yesno "Thanks for choosing The ADS-B Receiver Project to setup your receiver.\n\nMore information on this project as well as news, support, and discussions can be found on the projects official website located at:\n\n  https://www.adsbreceiver.net\n\nWould you like to continue setup?" 14 78
    CONTINUE_SETUP=$?
    if [[ "${CONTINUE_SETUP}" = 1 ]] ; then
    # Setup has been halted by the user.
        echo -e ""
        echo -e "\e[91m  \e[5mSETUP HALTED!\e[25m"
        echo -e "  Setup has been halted at the request of the user."
        echo -e ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
    fi
fi

## UPDATE THE REPOSITORY

UpdateRepository

## ASK IF OPERATING SYSTEM SHOULD BE UPDATED

if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${TITLE}" --title "Operating System Updates" --yesno "It is recommended that you update your system before building and/or installing any ADS-B receiver related packages. This script can do this for you at this time if you like.\n\nWould you like to update your operating system now?" 11 78
    case $? in
        0) UPDATE_OPERATING_SYSTEM="true" ;;
        1) UPDATE_OPERATING_SYSTEM="false" ;;
    esac
fi
if [[ "${UPDATE_OPERATING_SYSTEM}" = "true" ]] ; then
    UpdateOperatingSystem
fi

# Use function to detect cpu architecture.
if [[ -z "${CPU_ARCHITECTURE}" ]] ; then
    Check_CPU
    echo -e ""
fi

## EXECUTE BASH/MAIN.SH

chmod +x ${RECEIVER_BASH_DIRECTORY}/main.sh
${RECEIVER_BASH_DIRECTORY}/main.sh
if [[ $? -ne 0 ]] ; then
    echo -e "  \e[91m  ANY FURTHER SETUP AND/OR INSTALLATION REQUESTS HAVE BEEN TERMINIATED\e[39m"
    echo -e ""
    exit 1
fi

## INSTALLATION COMPLETE

# Display the installation complete message box.
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    whiptail --backtitle "${TITLE}" --title "Software Installation Complete" --msgbox "INSTALLATION COMPLETE\n\nDO NOT DELETE THIS DIRECTORY!\n\nFiles needed for certain items to run properly are contained within this directory. Deleting this directory may result in your receiver not working properly.\n\nHopefully, these scripts and files were found useful while setting up your ADS-B Receiver. Feedback regarding this software is always welcome. If you have any issues or wish to submit feedback, feel free to do so on GitHub.\n\nhttps://github.com/jprochazka/adsb-receiver" 20 65
fi

echo -e "\e[32m"
echo -e "\e[91m  Installation complete."
echo -e "\e[37m"

exit 0
