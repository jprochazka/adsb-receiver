#!/bin/bash

## INCLUDE EXTERNAL SCRIPTS

source ${RECEIVER_BASH_DIRECTORY}/variables.sh
source ${RECEIVER_BASH_DIRECTORY}/functions.sh


## BEGIN SETUP

clear
log_project_title ${RECEIVER_PROJECT_TITLE}
log_title_heading "Setting up the ADS-B Portal"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "ADS-B Portal Setup" \
              --yesno "The ADS-B Portal allows you to view performance graphs, system information, and live maps containing the current aircraft being tracked.\n\nBy enabling the portal's advanced features you can also view historical data on flight that has been seen in the past as well as view more detailed information on each of these aircraft.\n\nDo you wish to continue setting up the ADS-B Portal?" \
              23 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ADS-B Receiver Portal setup halted"
    echo ""
    exit 1
fi


## GATHER INSTALLATION INFORMATION FROM THE USER

# -----------------------------------------------------------------
# TODO: CHECK IF THE ADS-B PORTAL BACKEND AND FRONTEND IS INSTALLED
# -----------------------------------------------------------------

portal_installed = "false"
if [[ -f "" ]] ; then
    portal_installed = "true"
fi


## EXECUTE THE PROPER ADS-B PORTAL DATABASE CREATION SCRIPT

if [[ "${portal_installed}" = "false" ]]
    log_heading "Performing database setup"

    log_message "Asking the user which type of database engine should be used"
    database_engine = $(whiptail \
        --backtitle "${RECEIVER_PROJECT_TITLE}" \
        --title "Choose Database Engine" \
        --nocancel \
        --menu "Choose which database engine to use" \
        11 80 2 \
        "MySQL" "" "PostgreSQL" "" "SQLite" "")
    log_message "Database engine set to ${database_engine}"

check_package collectd-core
check_package rrdtool
check_package libpython3-stdlib

if [[ "$RECEIVER_MTA" == "POSTFIX" || -z "$RECEIVER_MTA" ]]; then
    check_package postfix
fi

case $RECEIVER_OS_DISTRIBUTION in
    ubuntu)
        php_version=""
        ;;
    debian)
        if [[ "${RECEIVER_OS_CODE_NAME}" == "bookworm" ]]; then php_version="8.2"; fi
        if [[ "${RECEIVER_OS_CODE_NAME}" == "bullseye" ]]; then php_version="7.4"; fi
        ;;
esac
check_package php${php_version}-cgi
if [[ ! "${php_version}" == "" && "${php_version}" < "8" ]]; then
    check_package php${php_version}-json
fi

if [[ "${advanced_installation}" = "true" ]]; then
    check_package python3-pyinotify
    check_package python3-apt
    case "${database_engine}" in
        "MySQL")
            check_package mariadb-client
            check_package python3-mysqldb
            check_package php${php_version}-mysql
            ;;
        "SQLite")
            check_package sqlite3
            check_package php${php_version}-sqlite3
            ;;
    esac
else
    check_package php${php_version}-xml
fi

log_message "Reloading the Lighttpd server"
sudo service lighttpd force-reload
echo ""


## SETUP THE ADS-B PORTAL

log_heading "Begining ADS-B Portal setup"

if [[ "${portal_installed}" = "true" && "${advanced_installation}" = "false" ]]; then
    log_message "Backing up the file ${lighttpd_document_root}/data/administrators.xml"
    sudo mv $lighttpd_document_root/data/administrators.xml $lighttpd_document_root/data/administrators.backup.xml
    log_message "Backing up the file ${lighttpd_document_root}/data/blogPosts.xml"
    sudo mv $lighttpd_document_root/data/blogPosts.xml $lighttpd_document_root/data/blogPosts.backup.xml
    log_message "Backing up the file ${lighttpd_document_root}/data/flightNotifications.xml"
    sudo mv $lighttpd_document_root/data/flightNotifications.xml $lighttpd_document_root/data/flightNotifications.backup.xml
    log_message "Backing up the file ${lighttpd_document_root}/data/settings.xml"
    sudo mv $lighttpd_document_root/data/settings.xml $lighttpd_document_root/data/settings.backup.xml
    log_message "Backing up the file ${lighttpd_document_root}/data/links.xml"
    sudo mv $lighttpd_document_root/data/links.xml $lighttpd_document_root/data/links.backup.xml
    log_message "Backing up the file ${lighttpd_document_root}/data/notifications.xml"
    sudo mv $lighttpd_document_root/data/notifications.xml $lighttpd_document_root/data/notifications.backup.xml
fi

if [ -f $lighttpd_document_root/index.lighttpd.html ]; then
    log_message "Removing default Lighttpd index file from document root"
    sudo rm $lighttpd_document_root/index.lighttpd.html
fi

log_message "Placing portal files in Lighttpd's root directory"
sudo cp -R $RECEIVER_BUILD_DIRECTORY/portal//html/* $lighttpd_document_root

if [[ "${portal_installed}" = "true" && "${advanced_installation}" = "false" ]]; then
    log_message "Restoring the backup copy of the file ${lighttpd_document_root}/data/administrators.xml"
    sudo mv $lighttpd_document_root/data/administrators.backup.xml $lighttpd_document_root/data/administrators.xml
    log_message "Restoring the backup copy of the file ${lighttpd_document_root}/data/blogPosts.xml"
    sudo mv $lighttpd_document_root/data/blogPosts.backup.xml $lighttpd_document_root/data/blogPosts.xml
    log_message "Restoring the backup copy of the file ${lighttpd_document_root}/data/flightNotifications.xml"
    sudo mv $lighttpd_document_root/data/flightNotifications.backup.xml $lighttpd_document_root/data/flightNotifications.xml
    log_message "Restoring the backup copy of the file ${lighttpd_document_root}/data/settings.xml"
    sudo mv $lighttpd_document_root/data/settings.backup.xml $lighttpd_document_root/data/settings.xml
    log_message "Restoring the backup copy of the file ${lighttpd_document_root}/data/links.xml"
    sudo mv $lighttpd_document_root/data/links.backup.xml $lighttpd_document_root/data/links.xml
    log_message "Restoring the backup copy of the file ${lighttpd_document_root}/data/notifications.xml"
    sudo mv $lighttpd_document_root/data/notifications.backup.xml $lighttpd_document_root/data/notifications.xml
fi

log_message "Making the directory ${lighttpd_document_root}/graphs/ writable"
sudo chmod 777 $lighttpd_document_root/graphs/
log_message "Making the directory ${lighttpd_document_root}/classes/ writable"
sudo chmod 777 $lighttpd_document_root/classes/
log_message "Making the directory ${lighttpd_document_root}/data/ writable"
sudo chmod 777 $lighttpd_document_root/data/
log_message "Making the files contained within the directory ${lighttpd_document_root}/data/ writable"
sudo chmod 666 $lighttpd_document_root/data/*

if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    log_message "Checking for the file upintheair.json in the dump1090 HTML folder"
    if [[ -f "/usr/share/dump1090-mutability/html/upintheair.json" || -f "/usr/share/dump1090-fa/html/upintheair.json" ]]; then
        log_message "Copying the file upintheair.json from the dump1090 HTML folder to the dump978 HTML folder"
        if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
            sudo cp /usr/share/dump1090-mutability/html/upintheair.json $lighttpd_document_root/dump978/
        fi
        if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
            sudo cp /usr/share/dump1090-fa/html/upintheair.json $lighttpd_document_root/dump978/
        fi
    fi
fi

if [[ -f "/etc/lighttpd/conf-available/87-adsb-portal.conf" ]] ; then
    log_message "Removing the existing Lighttpd ADS-B Portal configuration file"
    sudo rm -f /etc/lighttpd/conf-available/87-adsb-portal.conf
fi
log_message "Adding the Lighttpd portal configuration file"
sudo touch /etc/lighttpd/conf-available/87-adsb-portal.conf
if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    sudo tee -a /etc/lighttpd/conf-available/87-adsb-portal.conf > /dev/null <<EOF
# Add dump1090 as an alias to the dump1090-fa HTML folder.
alias.url += (
  "/dump1090/data/" => "/run/dump1090-fa/",
  "/dump1090/" => "/usr/share/skyaware/html/"
)
# Redirect the slash-less dump1090 URL
url.redirect += (
  "^/dump1090$" => "/dump1090/"
)
# Add CORS header
\$HTTP["url"] =~ "^/dump1090/data/.*\.json$" {
  setenv.add-response-header = ( "Access-Control-Allow-Origin" => "*" )
}
EOF
fi

if [[ ! -L "/etc/lighttpd/conf-enabled/87-adsb-portal.conf" ]] ; then
    log_message "Enabling the Lighttpd portal configuration file"
    sudo ln -s /etc/lighttpd/conf-available/87-adsb-portal.conf /etc/lighttpd/conf-enabled/87-adsb-portal.conf
fi

if [[ "${portal_installed}" = "false" ]] ; then
    log_message "Enabling the Lighttpd fastcgi-php module"
    echo ""
    sudo lighty-enable-mod fastcgi-php
    echo ""
fi

if pgrep "lighttpd" > /dev/null; then
    log_message "Reloading Lighttpd"
    sudo service lighttpd force-reload
else
    log_message "Starting Lighttpd"
    sudo service lighttpd start
fi


## SETUP THE ADS-B PORTAL MYSQL DATABASE

if [[ "${portal_installed}" = "false" && "${advanced_installation}" = "true" && "${database_engine}" = "MySQL" && "${database_exists}" = "false" ]]; then
    if [[ $(dpkg-query -W -f='${STATUS}' mariadb-server-10.1 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
        log_message "Switching the default MySQL plugin from unix_socket to mysql_native_password"
        sudo mysql -u${database_admin_user} -p${database_admin_password1} -h ${database_hostname}  -e "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE user = 'root' AND plugin = 'unix_socket';"
        log_message "Flushing privileges on the  MySQL (MariaDB) server"
        sudo mysql -u${database_admin_user} -p${database_admin_password1} -h ${database_hostname}  -e "FLUSH PRIVILEGES;"
        log_message "Reloading MySQL (MariaDB)"
        sudo service mysql force-reload
    fi

    log_message "Attempting to log into the MySQL server using the supplied administrator credentials"
    while ! sudo mysql -u${database_admin_user} -p${database_admin_password1} -h ${database_hostname}  -e ";"; do
        log_message "Unable to log into the MySQL server using the supplied administrator credentials"
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                 --title "Create MySQL Database" \
                 --msgbox "The script was not able to log into the MySQL server using the administrator credentials you supplied. You will now be asked to reenter the MySQL server administrator credentials." \
                 9 78
        database_admin_password1=""
        database_admin_password2=""
        log_message "Asking for the MySQL administrator username"
        database_admin_user_title="MySQL Administrator User"
        while [[ -z $database_admin_user ]]; do
            database_admin_user=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                           --title "${database_admin_user_title}" \
                                           --nocancel \
                                           --inputbox "Enter the MySQL administrator user." \
                                           8 78 \
                                           "${database_admin_user}" 3>&1 1>&2 2>&3)
            database_admin_user_title="MySQL Administrator User (REQUIRED)"
        done
        log_message "Asking for the MySQL administrator password"
        database_admin_password1_title="MySQL Administrator Password"
        while [[ -z $database_admin_password1 ]]; do
            database_admin_password1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                --title "${database_admin_password1_title}" \
                                                --nocancel \
                                                --passwordbox "Enter the password for the MySQL adminitrator user." \
                                                8 78 3>&1 1>&2 2>&3)
            database_admin_password1_title="MySQL Administrator Password (REQUIRED)"
        done
        log_message "Asking to confirm the MySQL administrator password"
        database_admin_password2_title="Confirm The MySQL Administrator Password"
        while [[ -z $database_admin_password2 ]] ; do
            database_admin_password2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                --title "${database_admin_password2_title}" \
                                                --nocancel \
                                                --passwordbox "Confirm the password for the MySQL adminitrator user." \
                                                8 78 3>&1 1>&2 2>&3)
            database_admin_password2_title="Confirm The MySQL Administrator Password (REQUIRED)"
        done
        while [[ ! "${database_admin_password1}" == "${database_admin_password2}" ]]; do
            log_message "Failed to log into MySQL using the supplied credentials"
            database_admin_password1=""
            database_admin_password2=""
            whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                     --title "Passwords Did Not Match" \
                     --msgbox "Passwords did not match.\nPlease enter your password again." \
                     9 78
            log_message "Asking for the MySQL administrator password"
            database_admin_password1_title="MySQL Administrator Password"
            while [[ -z $database_admin_password1 ]] ; do
                database_admin_password1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                  --title "${database_admin_password1_title}" \
                                                  --nocancel \
                                                  --passwordbox "Enter the password for the MySQL adminitrator user." \
                                                  8 78 3>&1 1>&2 2>&3)
                database_admin_password1_title="MySQL Administrator Password (REQUIRED)"
            done
            log_message "Asking to confirm the MySQL administrator password"
            database_admin_password2_title="Confirm The MySQL Administrator Password"
            while [[ -z $database_admin_password2 ]] ; do
                database_admin_password2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                    --title "${database_admin_password2_title}" \
                                                    --nocancel \
                                                    --passwordbox "Confirm the password for the MySQL adminitrator user." \
                                                    8 78 3>&1 1>&2 2>&3)
                database_admin_password2_title="Confirm The MySQL Administrator Password (REQUIRED)"
            done
        done
        log_message "Attempting to log into the MySQL server using the new administrator credentials"
    done
    log_message "Successfully logged into the MySQL server using the new administrator credentials"

    log_message "Creating the MySQL database ${database_name}"
    sudo mysql -u${database_admin_user} -p${database_admin_password1} -h ${database_hostname} -e "CREATE DATABASE ${database_name};"
    log_message "Creating the MySQL user ${database_user}"
    if [[ "${local_mysql_server}" = "false" ]] ; then
        sudo mysql -u${database_admin_user} -p${database_admin_password1} -h ${database_hostname} -e "CREATE USER '${database_user}'@'%' IDENTIFIED BY \"${database_password1}\";"
    else
        sudo mysql -u${database_admin_user} -p${database_admin_password1} -h ${database_hostname} -e "CREATE USER '${database_user}'@'localhost' IDENTIFIED BY \"${database_password1}\";"
    fi
    log_message "Granting priviledges on the MySQL database ${database_name} to the user ${database_user}"
    sudo mysql -u${database_admin_user} -p${database_admin_password1} -h ${database_hostname} -e "GRANT ALL PRIVILEGES ON ${database_name}.* TO '${database_user}'@'localhost';"
    log_message "Flushing priviledges on the MySQL database server"
    sudo mysql -u${database_admin_user} -p${database_admin_password1} -h ${database_hostname} -e "FLUSH PRIVILEGES;"
fi


## SETUP THE PERFORMANCE GRAPHS USING THE SCRIPT GRAPHS.SH

chmod +x $RECEIVER_BASH_DIRECTORY/portal/graphs.sh
$RECEIVER_BASH_DIRECTORY/portal/graphs.sh
if [[ $? -ne 0 ]] ; then
    echo ""
    log_alert_message "THE SCRIPT GRAPHS.SH ENCOUNTERED AN ERROR"
    echo ""
    exit 1
fi


## SETUP COMMON PORTAL FEATURES

if [ "${database_engine}" = "MySQL" ]; then
    export ADSB_PORTAL_DATABASE_ENGINE=$database_engine
    export ADSB_PORTAL_DATABASE_HOSTNAME=$database_hostname
    export ADSB_PORTAL_DATABASE_USER=$database_user
    export ADSB_PORTAL_DATABASE_PASSWORD1=$database_password1
    export ADSB_PORTAL_DATABASE_NAME=$database_name
elif [ "${database_engine}" = "SQLite" ]; then
    if [ -z $database_name ] ; then
        if [ ! -f $lighttpd_document_root/data/portal.sqlite ]; then
            log_message "Creating an empty SQLite database file"
            sudo touch $lighttpd_document_root/data/portal.sqlite
            log_message "Setting write permissions on the empty SQLite database file"
            sudo chmod 666 $lighttpd_document_root/data/portal.sqlite
        fi
        database_name="${lighttpd_document_root}/data/portal.sqlite"
    fi
    export ADSB_PORTAL_DATABASE_ENGINE=$database_engine
    export ADSB_PORTAL_DATABASE_HOSTNAME=""
    export ADSB_PORTAL_DATABASE_USER=""
    export ADSB_PORTAL_DATABASE_PASSWORD1=""
    export ADSB_PORTAL_DATABASE_NAME=$database_name
else
    export ADSB_PORTAL_DATABASE_ENGINE="xml"
    export ADSB_PORTAL_DATABASE_HOSTNAME=""
    export ADSB_PORTAL_DATABASE_USER=""
    export ADSB_PORTAL_DATABASE_PASSWORD1=""
    export ADSB_PORTAL_DATABASE_NAME=""
fi


## SETUP ADVANCED PORTAL FEATURES

if [[ "${advanced_installation}" == "true" ]] ; then
    chmod +x ${RECEIVER_BASH_DIRECTORY}/portal/advanced.sh
    ${RECEIVER_BASH_DIRECTORY}/portal/advanced.sh
    if [[ $? -ne 0 ]] ; then
        echo ""
        log_alert_message "THE SCRIPT ADVANCED.SH ENCOUNTERED AN ERROR"
        echo ""
        exit 1
    fi
fi


## SETUP ADS-B PORTAL BACKEND


## SETUP ADS-B PORTAL FRONTEND


## EXECUTE THE PERFORMANCE GRAPHS SETUP SCRIPT
log_heading "Performing performance graphs setup"

log_message "Executing the performance graphs setup script"
chmod +x ${RECEIVER_BASH_DIRECTORY}/portal/graphs.sh
${RECEIVER_BASH_DIRECTORY}/portal/graphs.sh
if [[ $? -ne 0 ]] ; then
    log_alert_heading "THE SCRIPT GRAPHS.SH ENCOUNTERED AN ERROR"
    log_alert_message "Setup has been halted due to error reported by the graphs.sh script"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "ADS-B Portal setup has been halted"
    exit 1
fi


## SETUP COMPLETE

log_heading "Performing post setup steps"
echo ""

log_message "Entering the ADS-B Receiver Project root directory"
cd ${RECEIVER_ROOT_DIRECTORY}
echo ""

log_title_message "------------------------------------------------------------------------------"
log_title_heading "ADS-B Portal setup is complete"
echo ""

exit 0