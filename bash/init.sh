#!/bin/bash

## CHECK IF THIS IS THE FIRST RUN USING AN IMAGE RELEASE

if [[ -f $RECEIVER_ROOT_DIRECTORY/image ]] ; then
    chmod +x $RECEIVER_BASH_DIRECTORY/image.sh
    $RECEIVER_BASH_DIRECTORY/image.sh
    if [[ $? != 0 ]] ; then
        echo -e "\n\n  \e[91m  IMAGE SETUP HAS BEEN TERMINATED.\e[39m\n"
        exit 1
    fi
    exit 0
fi


## INCLUDE EXTERNAL SCRIPTS

source $RECEIVER_BASH_DIRECTORY/functions.sh


## DISPLAY WELCOME SCREEN

if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "The ADS-B Receiver Project" --yesno "Thanks for choosing The ADS-B Receiver Project to setup your receiver.\n\nMore information on this project as well as news, support, and discussions can be found on the projects official website located at:\n\n  https://www.adsbreceiver.net\n\nWould you like to continue setup?" 14 78; then
    # Setup has been halted by the user.
    echo -e "\n\e[91m  \e[5mSETUP HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user.\e[37m\n"
    read -p "Press enter to continue..." discard
    exit 1
fi


## ATTEMPT TO UPDATE THE REPOSITORY

# Skip update if the development flag was set or the selected branch is not present in origin
if [[ $RECEIVER_DEVELOPMENT_MODE != "true" ]]; then
    current_branch=`git rev-parse --abbrev-ref HEAD`
    clear
    echo -e "\n\e[91m  ${RECEIVER_PROJECT_TITLE}\n"
    echo -e "\e[92m  Fetching the latest version of the '${RECEIVER_PROJECT_BRANCH}' branch."
    echo -e "\e[93m  -----------------------------------------------------------------------------\e[97m\n"

    # Ask if the user wishes to back up this branch if core files have been changed
    if [[ `git status --porcelain --untracked-files=no` && `git ls-remote --heads https://github.com/jprochazka/adsb-receiver.git refs/heads/master | wc -l` = 1 ]]; then
        if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Stash Changes To Branch '${current_branch}'" --defaultno --yesno "There appears to be changes to the current branch. In order to switch to or fetch the '${current_branch}' branch these changes will need to be stashed. Would you like to stash these changes now?" 14 78; then
            echo -e "\e[94m  Stashing changes to the ${current_branch} branch...\e[97m\n"
            git stash
            echo ""
        else
            echo -e "  \e[91m  SETUP HAS BEEN TERMINATED.\e[39m\n"
            exit 1
        fi
    fi

    # Checkout the appropriate branch
    if [[ "${current_branch}" != "${RECEIVER_PROJECT_BRANCH}" ]]; then
        echo -e "\e[94m  Switching to branch ${RECEIVER_PROJECT_BRANCH}...\e[97m\n"
        git checkout $RECEIVER_PROJECT_BRANCH
    fi

    # Fetch the most recent version of the branch from origin and reset any changes
    if [[ `git ls-remote --heads https://github.com/jprochazka/adsb-receiver.git refs/heads/$RECEIVER_PROJECT_BRANCH | wc -l` = 1 ]]; then
        echo -e "\n\e[94m  Fetching branch ${RECEIVER_PROJECT_BRANCH} from origin...\e[97m"
        git fetch origin
        echo -e "\e[94m  Performing hard reset of branch ${RECEIVER_PROJECT_BRANCH} so it matches origin/${RECEIVER_PROJECT_BRANCH}...\e[97m\n"
        git reset --hard origin/$RECEIVER_PROJECT_BRANCH
    else
        echo -e "\e[94m  The '${RECEIVER_PROJECT_BRANCH}' does not appear to be in origin...\e[97m"
    fi

    echo -e "\n\e[93m  -----------------------------------------------------------------------------"
    echo -e "\e[92m  Finished fetching the latest version the '${RECEIVER_PROJECT_BRANCH}' branch.\e[39m\n"
    read -p "Press enter to continue..." discard
fi


## ASK IF OPERATING SYSTEM SHOULD BE UPDATED

if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Operating System Updates" --yesno "It is recommended that you update your system before building and/or installing any ADS-B receiver related packages. This script can do this for you at this time if you like.\n\nWould you like to update your operating system now?" 11 78; then
    clear
    echo -e "\n\e[91m  ${RECEIVER_PROJECT_TITLE}\n"
    echo -e "\e[92m  Downloading and installing the latest updates for your operating system."
    echo -e "\e[93m  ------------------------------------------------------------------------\e[97m\n"
    sudo apt-get -y dist-upgrade
    echo -e "\n\e[93m  ------------------------------------------------------------------------"
    echo -e "\e[92m  Your operating system should now be up to date.\e[39m\n"
    read -p "Press enter to continue..." discard
fi


## EXECUTE BASH/MAIN.SH

chmod +x $RECEIVER_BASH_DIRECTORY/main.sh
bash $RECEIVER_BASH_DIRECTORY/main.sh
if [[ $? -ne 0 ]] ; then
    echo -e "\e[91m  ANY FURTHER SETUP AND/OR INSTALLATION REQUESTS HAVE BEEN TERMINIATED\e[39m\n"
    exit 1
fi

## INSTALLATION COMPLETE

# Display the installation complete message box
whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "Software Installation Complete" --msgbox "INSTALLATION COMPLETE\n\nDO NOT DELETE THIS DIRECTORY!\n\nFiles needed for certain items to run properly are contained within this directory. Deleting this directory may result in your receiver not working properly.\n\nHopefully, these scripts and files were found useful while setting up your ADS-B Receiver. Feedback regarding this software is always welcome. If you have any issues or wish to submit feedback, feel free to do so on GitHub.\n\n  https://github.com/jprochazka/adsb-receiver" 20 65
echo -e "\n\e[91m  Installation complete.\n"

exit 0
