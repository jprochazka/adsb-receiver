#!/bin/bash

## PRE EXECUTION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh


## DISPLAY THE WELCOME SCREEN

LogHeading "Displaying the welcome message"

LogMessage "Displaying the welcome message to the user"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "The ADS-B Receiver Project" \
              --yesno "Thanks for choosing The ADS-B Receiver Project to setup your receiver.\n\nMore information on this project as well as news, support, and discussions can be found on the projects official website located at:\n\n  https://www.adsbreceiver.net\n\nWould you like to continue setup?" \
              14 78; then
    LogAlertHeading "INSTALLATION HALTED"
    LogAlertMessage "Setup has been halted at the request of the user"
    exit 1
fi


## ATTEMPT TO CHANGE AND/OR UPDATE THE REPOSITORY

if [[ $RECEIVER_DEVELOPMENT_MODE != "true" ]]; then
    current_branch=`git rev-parse --abbrev-ref HEAD`

    clear
    LogProjectTitle
    LogTitleHeading "Fetching the latest version of the ${RECEIVER_PROJECT_BRANCH} branch"
    LogTitleMessage "------------------------------------------------------------------------------"
    echo ""

    LogHeading "Checking out and updating the appropriate branch"

    if [[ `git status --porcelain --untracked-files=no` && `git ls-remote --heads https://github.com/jprochazka/adsb-receiver.git refs/heads/master | wc -l` = 1 ]]; then
        if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                    --title "Stash Changes To Branch ${current_branch}" \
                    --defaultno \
                    --yesno "There appears to be changes to the current branch. In order to switch to or fetch the ${current_branch} branch these changes will need to be stashed. Would you like to stash these changes now?" \
                    14 78; then
            LogMessage "Stashing changes made to the ${current_branch} branch"
            git stash
            echo ""
        else
            LogAlertHeading "INSTALLATION HALTED"
            LogAlertMessage "Setup has been halted at the request of the user"
            exit 1
        fi
    fi

    if [[ "${current_branch}" != "${RECEIVER_PROJECT_BRANCH}" ]]; then
        LogMessage "Switching to branch ${RECEIVER_PROJECT_BRANCH}"
        echo ""
        git checkout $RECEIVER_PROJECT_BRANCH
        echo ""
    fi

    if [[ `git ls-remote --heads https://github.com/jprochazka/adsb-receiver.git refs/heads/$RECEIVER_PROJECT_BRANCH | wc -l` = 1 ]]; then
        LogMessage "Fetching branch ${RECEIVER_PROJECT_BRANCH} from origin"
        echo ""
        git fetch origin
        echo ""
        LogMessage "Performing hard reset of branch ${RECEIVER_PROJECT_BRANCH} so it matches origin/${RECEIVER_PROJECT_BRANCH}"
        echo ""
        git reset --hard origin/$RECEIVER_PROJECT_BRANCH
    else
        LogMessage "The branch ${RECEIVER_PROJECT_BRANCH} does not appear to be in origin"
    fi

    LogTitleMessage "-----------------------------------------------------------------------------"
    LogTitleHeading "Finished fetching the latest version the '${RECEIVER_PROJECT_BRANCH}' branch."
    echo ""
    read -p "Press enter to continue..." discard
fi


## ASK IF OPERATING SYSTEM SHOULD BE UPDATED

LogHeading "Performing operating system updates if so desired"

LogMessage "Asking the user if they wish to update the operating system"
if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "Operating System Updates" \
            --yesno "It is recommended that you update your system before building and/or installing any ADS-B receiver related packages. This script can do this for you at this time if you like.\n\nWould you like to update your operating system now?" \
            11 78; then
    clear
    LogProjectTitle
    LogTitleHeading "Downloading and installing the latest updates for your operating system"
    LogTitleMessage "------------------------------------------------------------------------------"
    echo ""
    LogMessage "Updating the operating system using apt-get"
    echo ""
    sudo apt-get -y dist-upgrade
    echo ""
    LogTitleMessage "------------------------------------------------------------------------"
    LogTitleHeading "Your operating system should now be up to date"
    echo ""
    read -p "Press enter to continue..." discard
fi


## EXECUTE BASH/MAIN.SH

LogHeading "Executing the script bash/main.sh"

LogMessage "Adding execute permissions to bash/main"
chmod +x $RECEIVER_BASH_DIRECTORY/main.sh

LogMessage "Executing bash/main"
bash $RECEIVER_BASH_DIRECTORY/main.sh
if [[ $? -ne 0 ]] ; then
    echo ""
    LogAlertHeading "ANY FURTHER SETUP AND/OR INSTALLATION REQUESTS HAVE BEEN TERMINIATED"
    echo ""
    exit 1
fi


## INSTALLATION COMPLETE

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "Software Installation Complete" \
         --msgbox "INSTALLATION COMPLETE\n\nDO NOT DELETE THIS DIRECTORY!\n\nFiles needed for certain items to run properly are contained within this directory. Deleting this directory may result in your receiver not working properly.\n\nHopefully, these scripts and files were found useful while setting up your ADS-B Receiver. Feedback regarding this software is always welcome. If you have any issues or wish to submit feedback, feel free to do so on GitHub.\n\n  https://github.com/jprochazka/adsb-receiver" \
         20 65
LogProjectName "Installation complete"

exit 0
