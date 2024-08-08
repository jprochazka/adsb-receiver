#!/bin/bash

## PRE INSTALLATION OPERATIONS

source $RECEIVER_BASH_DIRECTORY/variables.sh
source $RECEIVER_BASH_DIRECTORY/functions.sh

clear
log_project_title
log_title_heading "Setting up The ADS-B Portal"
log_title_message "------------------------------------------------------------------------------"
if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
              --title "The ADS-B Portal Setup" \
              --yesno "The ADS-B Portal adds a web accessable portal to your receiver. The portal contains allows you to view performance graphs, system information, and live maps containing the current aircraft being tracked.\n\nBy enabling the portal's advanced features you can also view historical data on flight that have been seen in the past as well as view more detailed information on each of these aircraft.\n\nTHE ADVANCED PORTAL FEATURES ARE STILL IN DEVELOPMENT\n\nIt is recomended that only those wishing to contribute to the development of these features or those wishing to test out the new features enable them. Do not be surprised if you run into any major bugs after enabling the advanced features at this time!\n\nDo you wish to continue with the ADS-B Receiver Project Portal setup?" \
              23 78; then
    echo ""
    log_alert_heading "INSTALLATION HALTED"
    log_alert_message "Setup has been halted at the request of the user"
    echo ""
    log_title_message "------------------------------------------------------------------------------"
    log_title_heading "The ADS-B Portal setup halted"
    echo ""
    exit 1
fi


## INSTALL LIGHTTPD IF IT IS NOT ALREADY INSTALLED

log_heading "Installing Lighttpd if not already installed"

check_package lighttpd

log_message "Determining the lighttpd document root"
RAW_DOCUMENT_ROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
LIGHTTPD_DOCUMENT_ROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< ${RAW_DOCUMENT_ROOT}`


## GATHER REQUIRED INFORMATION

log_heading "Gather information required to configure the portal"

log_message "Determining if a portal installation exists"
if [[ -f "${LIGHTTPD_DOCUMENT_ROOT}/classes/settings.class.php" ]]; then
    log_message "An instance of The ADS-B Portal is installed"
    RECEIVER_PORTAL_INSTALLED="true"
else
    log_message "The ADS-B Portal is not installed"
    RECEIVER_PORTAL_INSTALLED="false"
fi

if [[ "${RECEIVER_PORTAL_INSTALLED}" = "true" ]]; then
    log_message "Gathering information needed to proceed with setup"
    DATABASEENGINE=`grep 'db_driver' ${LIGHTTPD_DOCUMENT_ROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    if [[ "${DATABASEENGINE}" = "xml" ]]; then
        log_message "This is a lite installation of the portal"
        ADVANCED="false"
    else
        log_message "This is an advanced installation of the portal"
        ADVANCED="true"
    fi
    if [[ "${ADVANCED}" = "true" ]]; then
        case "${DATABASEENGINE}" in
            "mysql")
                log_message "The MySQL database engine is being used"
                DATABASEENGINE="MySQL"
                ;;
            "sqlite")
                log_message "The SQLite database engine is being used"
                DATABASEENGINE="SQLite"
                ;;
        esac
        DATABASEHOSTNAME=`grep 'db_host' ${LIGHTTPD_DOCUMENT_ROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
        DATABASEUSER=`grep 'db_username' ${LIGHTTPD_DOCUMENT_ROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
        DATABASEPASSWORD1=`grep 'db_password' ${LIGHTTPD_DOCUMENT_ROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
        DATABASENAME=`grep 'db_database' ${LIGHTTPD_DOCUMENT_ROOT}/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    fi
else
    log_message "Asking if advanced features should be utilized"
    if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                --title "Portal Type Selection" \
                --defaultno \
                --yesno "NOTE THAT THE ADVANCED FEATURES ARE STILL IN DEVELOPMENT AT THIS TIME\nADVANCED FEATURES SHOULD ONLY BE ENABLED BY DEVELOPERS AND TESTERS ONLY\n\nBy enabling advanced features the portal will log all flights seen as well as the path of the flight. This data is stored in either a MySQL or SQLite database. This will result in a lot more data being stored on your devices hard drive. Keep this and your devices hardware capabilities in mind before selecting to enable these features.\n\nENABLING ADVANCED FEATURES ON DEVICES USING SD CARDS CAN SHORTEN THE LIFE OF THE SD CARD IMMENSELY\n\nDo you wish to enable the portal advanced features?" \
                19 78; then
        log_message "Advanced features will be setup"
        ADVANCED="true"
    else
        log_message "Lite features will be setup"
        ADVANCED="false"
    fi

    if [[ "${ADVANCED}" = "true" ]]; then
        log_message "Asking for the location of the MySQL server"
        DATABASEENGINE=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                  --title "Choose Database Type" \
                                  --nocancel \
                                  --menu "Choose which database engine to use." 11 80 2 \
                                  "MySQL" "" "SQLite" "" 3>&1 1>&2 2>&3)
        if [[ "${DATABASEENGINE}" = "MySQL" ]]; then
            if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                        --title "MySQL Database Location" \
                        --yesno "Will the database be hosted locally on this device?" \
                        7 80; then
                log_message "A local MySQL database server will be used"
                LOCALMYSQLSERVER="true"
            else
                log_message "A remote MySQL database server will be used"
            fi

            if [[ "${LOCALMYSQLSERVER}" = "false" ]]; then
                log_message "Asking for the remote MySQL server's hostname"
                DATABASEHOSTNAME_TITLE="MySQL Database Server Hostname"
                while [[ -z "${DATABASEHOSTNAME}" ]]; do
                    DATABASEHOSTNAME=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                --title "${DATABASEHOSTNAME_TITLE}" \
                                                --nocancel \
                                                --inputbox "What is the remote MySQL server's hostname?" \
                                                10 60 3>&1 1>&2 2>&3)
                    DATABASEHOSTNAME_TITLE="MySQL Database Server Hostname (REQUIRED)"
                done
                log_message "Asking for the database already exists remotly"
                if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                            --title "Does MySQL Database Exist" \
                            --yesno "Has the database already been created?" \
                            7 80; then
                    log_message "The database exists on the remote server"
                    DATABASEEXISTS="true"
                else
                    log_message "The database does not exist on the remote server"
                    DATABASEEXISTS="false"
                fi
            fi

            if [[ "${LOCALMYSQLSERVER}" = "true" || "${DATABASEEXISTS}" = "false" ]]; then
                whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                         --title "Create Remote MySQL Database" \
                         --msgbox "This script can attempt to create the MySQL database for you.\nYou will now be asked for the credentials for a MySQL user who has the ability to create a database on the MySQL server." \
                         9 78

                log_message "Asking for the MySQL administrator username"
                DATABASEADMINUSER_TITLE="MySQL Administrator Username"
                while [[ -z "${DATABASEADMINUSER}" ]]; do
                    DATABASEADMINUSER=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                 --title "${DATABASEADMINUSER_TITLE}" \
                                                 --nocancel \
                                                 --inputbox "Enter the MySQL adminitrator username." \
                                                 8 78 \
                                                 "root" 3>&1 1>&2 2>&3)
                    DATABASEADMINUSER_TITLE="MySQL Administrator User (REQUIRED)"
                done

                log_message "Asking for the MySQL administrator password"
                DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password"
                while [[ -z "${DATABASEADMINPASSWORD1}" ]]; do
                    DATABASEADMINPASSWORD1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                      --title "${DATABASEADMINPASSWORD1_TITLE}" \
                                                      --nocancel \
                                                      --passwordbox "Enter the password for the MySQL adminitrator user." \
                                                      8 78 3>&1 1>&2 2>&3)
                    DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password (REQUIRED)"
                done
                log_message "Asking the user to confirm the MySQL administrator password"
                DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password"
                while [[ -z "${DATABASEADMINPASSWORD2}" ]]; do
                    DATABASEADMINPASSWORD2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                      --title "${DATABASEADMINPASSWORD2_TITLE}" \
                                                      --nocancel \
                                                      --passwordbox "Confirm the password for the MySQL adminitrator user." \
                                                      8 78 3>&1 1>&2 2>&3)
                    DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password (REQUIRED)"
                done
                while [[ ! "${DATABASEADMINPASSWORD1}" = "${DATABASEADMINPASSWORD2}" ]]; do
                    log_message "The supplied MySQL administrator passwords did not match"
                    DATABASEADMINPASSWORD1=""
                    DATABASEADMINPASSWORD2=""
                    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                             --title "Passwords Did Not Match" \
                             --msgbox "Passwords did not match.\nPlease enter the MySQL administrator password again." \
                             9 78
                    log_message "Asking for the MySQL administrator password"
                    DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password"
                    while [[ -z "${DATABASEADMINPASSWORD1}" ]]; do
                        DATABASEADMINPASSWORD1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                          --title "${DATABASEADMINPASSWORD1_TITLE}" \
                                                          --nocancel \
                                                          --passwordbox "DATABASEADMINPASSWORD1_MESSAGE" \
                                                          8 78 3>&1 1>&2 2>&3)
                        DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password (REQUIRED)"
                    done
                    log_message "Asking the user to confirm the MySQL administrator password"
                    DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password"
                    while [[ -z "${DATABASEADMINPASSWORD2}" ]]; do
                        DATABASEADMINPASSWORD2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                          --title "${DATABASEADMINPASSWORD2_TITLE}" \
                                                          --nocancel \
                                                          --passwordbox "DATABASEADMINPASSWORD2_MESSAGE" \
                                                          8 78 3>&1 1>&2 2>&3)
                        DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password (REQUIRED)"
                    done
                done
            fi

            log_message "Asking for the name of the ADS-B Portal database"
            DATABASENAME_TITLE="The ADS-B Portal Database Name"
            while [[ -z "${DATABASENAME}" ]]; do
                DATABASENAME=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                        --title "${DATABASENAME_TITLE}" \
                                        --nocancel \
                                        --inputbox "Enter your ADS-B Receiver Portal database name." \
                                        8 78 3>&1 1>&2 2>&3)
                DATABASENAME_TITLE="The ADS-B Portal Database Name (REQUIRED)"
            done

            log_message "Asking for the ADS-B Portal database username"
            DATABASEUSER_TITLE="The ADS-B Portal Database User"
            while [[ -z "${DATABASEUSER}" ]]; do
                DATABASEUSER=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                        --title "${DATABASEUSER_TITLE}" \
                                        --nocancel \
                                        --inputbox "Enter the user for the ADS-B Receiver Portal database." \
                                        8 78 3>&1 1>&2 2>&3)
                DATABASEUSER_TITLE="The ADS-B Portal Database User (REQUIRED)"
            done

            log_message "Asking for the ADS-B Portal database password"
            DATABASEPASSWORD1_TITLE="The ADS-B Portal Database Password"
            while [[ -z "${DATABASEPASSWORD1}" ]]; do
                DATABASEPASSWORD1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                             --title "${DATABASEPASSWORD1_TITLE}" \
                                             --nocancel \
                                             --passwordbox "Enter the ADS-B Portal database password." \
                                             8 78 3>&1 1>&2 2>&3)
                DATABASEPASSWORD1_TITLE="The ADS-B Portal Database Password (REQUIRED)"
            done
            log_message "Asking the user to confirm the ADS-B Portal database password"
            DATABASEPASSWORD2_TITLE="Confirm The ADS-B Portal Database Password"
            while [[ -z "${DATABASEPASSWORD2}" ]]; do
                DATABASEPASSWORD2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                             --title "${DATABASEPASSWORD2_TITLE}" \
                                             --nocancel \
                                             --passwordbox "Confirm the ADS-B Portal database password." \
                                             8 78 3>&1 1>&2 2>&3)
                DATABASEPASSWORD2_TITLE="Confirm The ADS-B Portal Database Password (REQUIRED)"
            done

            while [[ ! "${DATABASEPASSWORD1}" = "${DATABASEPASSWORD2}" ]]; do
                log_message "The supplied ADS-B Portal database passwords did not match"
                DATABASEPASSWORD1=""
                DATABASEPASSWORD2=""
                whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                         --title "Passwords Did Not Match" \
                         --msgbox "Passwords did not match.\nPlease enter the ADS-B Portal password again." \
                         9 78
                log_message "Asking for the ADS-B Portal database password"
                DATABASEPASSWORD1_TITLE="The ADS-B Portal Database Password"
                while [[ -z "${DATABASEPASSWORD1}" ]]; do
                    DATABASEPASSWORD1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                 --title "${DATABASEPASSWORD1_TITLE}" \
                                                 --nocancel \
                                                 --passwordbox "${DATABASEPASSWORD1_MESSAGE}" \
                                                 8 78 3>&1 1>&2 2>&3)
                    DATABASEPASSWORD1_TITLE="The ADS-B Portal Database Password (REQUIRED)"
                done
                log_message "Asking the user to confirm the ADS-B Portal database password"
                DATABASEPASSWORD2_TITLE="Confirm The ADS-B Portal Database Password"
                while [[ -z "${DATABASEPASSWORD2}" ]]; do
                    DATABASEPASSWORD2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                 --title "${DATABASEPASSWORD2_TITLE}" \
                                                 --nocancel \
                                                 --passwordbox "${DATABASEPASSWORD2_MESSAGE}" \
                                                 8 78 3>&1 1>&2 2>&3)
                    DATABASEPASSWORD2_TITLE="Confirm The ADS-B Portal Database Password (REQUIRED)"
                done
            done
        fi
    fi
fi


## INSTALL PREREQUISITE PACAKGES

if [[ "${LOCALMYSQLSERVER}" = "true" ]]; then
    DATABASEEXISTS="false"
    DATABASEHOSTNAME="localhost"

    check_package mariadb-server
    log_message "Executing the mysql_secure_installation script"
    sudo mysql_secure_installation
fi

check_package collectd-core
check_package rrdtool
check_package libpython3-stdlib

if [[ "$RECEIVER_MTA" == "POSTFIX" || -z "$RECEIVER_MTA" ]]; then
    check_package postfix
fi

case $RECEIVER_OS_DISTRIBUTION in
    ubuntu)
        DISTRO_PHP_VERSION=""
        ;;
    debian)
        if [[ "${RECEIVER_OS_CODE_NAME}" == "bookworm" ]]; then DISTRO_PHP_VERSION="8.2"; fi
        if [[ "${RECEIVER_OS_CODE_NAME}" == "bullseye" ]]; then DISTRO_PHP_VERSION="7.4"; fi
        ;;
esac
check_package php${DISTRO_PHP_VERSION}-cgi
if [[ ! "${DISTRO_PHP_VERSION}" == "" && "${DISTRO_PHP_VERSION}" < "8" ]]; then
    check_package php${DISTRO_PHP_VERSION}-json
fi

if [[ "${ADVANCED}" = "true" ]]; then
    check_package python3-pyinotify
    check_package python3-apt
    case "${DATABASEENGINE}" in
        "MySQL")
            check_package mariadb-client
            check_package python3-mysqldb
            check_package php${DISTRO_PHP_VERSION}-mysql
            ;;
        "SQLite")
            check_package sqlite3
            check_package php${DISTRO_PHP_VERSION}-sqlite3
            ;;
    esac
else
    check_package php${DISTRO_PHP_VERSION}-xml
fi

log_message "Reloading the Lighttpd server"
sudo service lighttpd force-reload
echo ""


## SETUP THE ADS-B PORTAL

log_heading "Begining ADS-B Portal setup"

if [[ "${RECEIVER_PORTAL_INSTALLED}" = "true" && "${ADVANCED}" = "false" ]]; then
    log_message "Backing up the file ${LIGHTTPD_DOCUMENT_ROOT}/data/administrators.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/administrators.xml $LIGHTTPD_DOCUMENT_ROOT/data/administrators.backup.xml
    log_message "Backing up the file ${LIGHTTPD_DOCUMENT_ROOT}/data/blogPosts.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/blogPosts.xml $LIGHTTPD_DOCUMENT_ROOT/data/blogPosts.backup.xml
    log_message "Backing up the file ${LIGHTTPD_DOCUMENT_ROOT}/data/flightNotifications.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/flightNotifications.xml $LIGHTTPD_DOCUMENT_ROOT/data/flightNotifications.backup.xml
    log_message "Backing up the file ${LIGHTTPD_DOCUMENT_ROOT}/data/settings.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/settings.xml $LIGHTTPD_DOCUMENT_ROOT/data/settings.backup.xml
    log_message "Backing up the file ${LIGHTTPD_DOCUMENT_ROOT}/data/links.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/links.xml $LIGHTTPD_DOCUMENT_ROOT/data/links.backup.xml
    log_message "Backing up the file ${LIGHTTPD_DOCUMENT_ROOT}/data/notifications.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/notifications.xml $LIGHTTPD_DOCUMENT_ROOT/data/notifications.backup.xml
fi

if [ -f $LIGHTTPD_DOCUMENT_ROOT/index.lighttpd.html ]; then
    log_message "Removing default Lighttpd index file from document root"
    sudo rm $LIGHTTPD_DOCUMENT_ROOT/index.lighttpd.html
fi

log_message "Placing portal files in Lighttpd's root directory"
sudo cp -R $RECEIVER_BUILD_DIRECTORY/portal//html/* $LIGHTTPD_DOCUMENT_ROOT

if [[ "${RECEIVER_PORTAL_INSTALLED}" = "true" && "${ADVANCED}" = "false" ]]; then
    log_message "Restoring the backup copy of the file ${LIGHTTPD_DOCUMENT_ROOT}/data/administrators.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/administrators.backup.xml $LIGHTTPD_DOCUMENT_ROOT/data/administrators.xml
    log_message "Restoring the backup copy of the file ${LIGHTTPD_DOCUMENT_ROOT}/data/blogPosts.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/blogPosts.backup.xml $LIGHTTPD_DOCUMENT_ROOT/data/blogPosts.xml
    log_message "Restoring the backup copy of the file ${LIGHTTPD_DOCUMENT_ROOT}/data/flightNotifications.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/flightNotifications.backup.xml $LIGHTTPD_DOCUMENT_ROOT/data/flightNotifications.xml
    log_message "Restoring the backup copy of the file ${LIGHTTPD_DOCUMENT_ROOT}/data/settings.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/settings.backup.xml $LIGHTTPD_DOCUMENT_ROOT/data/settings.xml
    log_message "Restoring the backup copy of the file ${LIGHTTPD_DOCUMENT_ROOT}/data/links.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/links.backup.xml $LIGHTTPD_DOCUMENT_ROOT/data/links.xml
    log_message "Restoring the backup copy of the file ${LIGHTTPD_DOCUMENT_ROOT}/data/notifications.xml"
    sudo mv $LIGHTTPD_DOCUMENT_ROOT/data/notifications.backup.xml $LIGHTTPD_DOCUMENT_ROOT/data/notifications.xml
fi

log_message "Making the directory ${LIGHTTPD_DOCUMENT_ROOT}/graphs/ writable"
sudo chmod 777 $LIGHTTPD_DOCUMENT_ROOT/graphs/
log_message "Making the directory ${LIGHTTPD_DOCUMENT_ROOT}/classes/ writable"
sudo chmod 777 $LIGHTTPD_DOCUMENT_ROOT/classes/
log_message "Making the directory ${LIGHTTPD_DOCUMENT_ROOT}/data/ writable"
sudo chmod 777 $LIGHTTPD_DOCUMENT_ROOT/data/
log_message "Making the files contained within the directory ${LIGHTTPD_DOCUMENT_ROOT}/data/ writable"
sudo chmod 666 $LIGHTTPD_DOCUMENT_ROOT/data/*

if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
    log_message "Checking for the file upintheair.json in the dump1090 HTML folder"
    if [[ -f "/usr/share/dump1090-mutability/html/upintheair.json" || -f "/usr/share/dump1090-fa/html/upintheair.json" ]]; then
        log_message "Copying the file upintheair.json from the dump1090 HTML folder to the dump978 HTML folder"
        if [[ $(dpkg-query -W -f='${STATUS}' dump1090-mutability 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
            sudo cp /usr/share/dump1090-mutability/html/upintheair.json ${LIGHTTPD_DOCUMENT_ROOT}/dump978/
        fi
        if [[ $(dpkg-query -W -f='${STATUS}' dump1090-fa 2>/dev/null | grep -c "ok installed") -eq 1 ]]; then
            sudo cp /usr/share/dump1090-fa/html/upintheair.json ${LIGHTTPD_DOCUMENT_ROOT}/dump978/
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

if [[ "${RECEIVER_PORTAL_INSTALLED}" = "false" ]] ; then
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

if [[ "${RECEIVER_PORTAL_INSTALLED}" = "false" && "${ADVANCED}" = "true" && "${DATABASEENGINE}" = "MySQL" && "${DATABASEEXISTS}" = "false" ]]; then
    if [[ $(dpkg-query -W -f='${STATUS}' mariadb-server-10.1 2>/dev/null | grep -c "ok installed") -eq 1 ]] ; then
        log_message "Switching the default MySQL plugin from unix_socket to mysql_native_password"
        sudo mysql -u${DATABASEADMINUSER} -p${DATABASEADMINPASSWORD1} -h ${DATABASEHOSTNAME}  -e "UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE user = 'root' AND plugin = 'unix_socket';"
        log_message "Flushing privileges on the  MySQL (MariaDB) server"
        sudo mysql -u${DATABASEADMINUSER} -p${DATABASEADMINPASSWORD1} -h ${DATABASEHOSTNAME}  -e "FLUSH PRIVILEGES;"
        log_message "Reloading MySQL (MariaDB)"
        sudo service mysql force-reload
    fi

    log_message "Attempting to log into the MySQL server using the supplied administrator credentials"
    while ! sudo mysql -u${DATABASEADMINUSER} -p${DATABASEADMINPASSWORD1} -h ${DATABASEHOSTNAME}  -e ";"; do
        log_message "Unable to log into the MySQL server using the supplied administrator credentials"
        whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                 --title "Create MySQL Database" \
                 --msgbox "The script was not able to log into the MySQL server using the administrator credentials you supplied. You will now be asked to reenter the MySQL server administrator credentials." \
                 9 78
        DATABASEADMINPASSWORD1=""
        DATABASEADMINPASSWORD2=""
        log_message "Asking for the MySQL administrator username"
        DATABASEADMINUSER_TITLE="MySQL Administrator User"
        while [[ -z "${DATABASEADMINUSER}" ]]; do
            DATABASEADMINUSER=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                         --title "${DATABASEADMINUSER_TITLE}" \
                                         --nocancel \
                                         --inputbox "Enter the MySQL administrator user." \
                                         8 78 \
                                         "${DATABASEADMINUSER}" 3>&1 1>&2 2>&3)
            DATABASEADMINUSER_TITLE="MySQL Administrator User (REQUIRED)"
        done
        log_message "Asking for the MySQL administrator password"
        DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password"
        DATABASEADMINPASSWORD1_MESSAGE="Enter the password for the MySQL adminitrator user."
        while [[ -z "${DATABASEADMINPASSWORD1}" ]]; do
            DATABASEADMINPASSWORD1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                              --title "${DATABASEADMINPASSWORD1_TITLE}" \
                                              --nocancel \
                                              --passwordbox "${DATABASEADMINPASSWORD1_MESSAGE}" \
                                              8 78 3>&1 1>&2 2>&3)
            DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password (REQUIRED)"
        done
        log_message "Asking to confirm the MySQL administrator password"
        DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password"
        DATABASEADMINPASSWORD2_MESSAGE="\nConfirm the password for the MySQL adminitrator user."
        while [[ -z "${DATABASEADMINPASSWORD2}" ]] ; do
            DATABASEADMINPASSWORD2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                              --title "${DATABASEADMINPASSWORD2_TITLE}" \
                                              --nocancel \
                                              --passwordbox "${DATABASEADMINPASSWORD2_MESSAGE}" \
                                              8 78 3>&1 1>&2 2>&3)
            DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password (REQUIRED)"
        done
        while [[ ! "${DATABASEADMINPASSWORD1}" == "${DATABASEADMINPASSWORD2}" ]]; do
            log_message "Failed to log into MySQL using the supplied credentials"
            DATABASEADMINPASSWORD1=""
            DATABASEADMINPASSWORD2=""
            whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                     --title "Passwords Did Not Match" \
                     --msgbox "Passwords did not match.\nPlease enter your password again." \
                     9 78
            log_message "Asking for the MySQL administrator password"
            DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password"
            while [[ -z "${DATABASEADMINPASSWORD1}" ]] ; do
                DATABASEADMINPASSWORD1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                  --title "${DATABASEADMINPASSWORD1_TITLE}" \
                                                  --nocancel \
                                                  --passwordbox "DATABASEADMINPASSWORD1_MESSAGE" \
                                                  8 78 3>&1 1>&2 2>&3)
                DATABASEADMINPASSWORD1_TITLE="MySQL Administrator Password (REQUIRED)"
            done
            log_message "Asking to confirm the MySQL administrator password"
            DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password"
            while [[ -z "${DATABASEADMINPASSWORD2}" ]] ; do
                DATABASEADMINPASSWORD2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                  --title "${DATABASEADMINPASSWORD2_TITLE}" \
                                                  --nocancel \
                                                  --passwordbox "DATABASEADMINPASSWORD2_MESSAGE" \
                                                  8 78 3>&1 1>&2 2>&3)
                DATABASEADMINPASSWORD2_TITLE="Confirm The MySQL Administrator Password (REQUIRED)"
            done
        done
        log_message "Attempting to log into the MySQL server using the new administrator credentials"
    done
    log_message "Successfully logged into the MySQL server using the new administrator credentials"

    log_message "Creating the MySQL database ${DATABASENAME}"
    sudo mysql -u${DATABASEADMINUSER} -p${DATABASEADMINPASSWORD1} -h ${DATABASEHOSTNAME} -e "CREATE DATABASE ${DATABASENAME};"
    log_message "Creating the MySQL user ${DATABASEUSER}"
    if [[ "${LOCALMYSQLSERVER}" = "false" ]] ; then
        sudo mysql -u${DATABASEADMINUSER} -p${DATABASEADMINPASSWORD1} -h ${DATABASEHOSTNAME} -e "CREATE USER '${DATABASEUSER}'@'%' IDENTIFIED BY \"${DATABASEPASSWORD1}\";"
    else
        sudo mysql -u${DATABASEADMINUSER} -p${DATABASEADMINPASSWORD1} -h ${DATABASEHOSTNAME} -e "CREATE USER '${DATABASEUSER}'@'localhost' IDENTIFIED BY \"${DATABASEPASSWORD1}\";"
    fi
    log_message "Granting priviledges on the MySQL database ${DATABASENAME} to the user ${DATABASEUSER}"
    sudo mysql -u${DATABASEADMINUSER} -p${DATABASEADMINPASSWORD1} -h ${DATABASEHOSTNAME} -e "GRANT ALL PRIVILEGES ON ${DATABASENAME}.* TO '${DATABASEUSER}'@'localhost';"
    log_message "Flushing priviledges on the MySQL database server"
    sudo mysql -u${DATABASEADMINUSER} -p${DATABASEADMINPASSWORD1} -h ${DATABASEHOSTNAME} -e "FLUSH PRIVILEGES;"
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

if [ "${DATABASEENGINE}" = "MySQL" ]; then
    export ADSB_DATABASEENGINE=${DATABASEENGINE}
    export ADSB_DATABASEHOSTNAME=${DATABASEHOSTNAME}
    export ADSB_DATABASEUSER=${DATABASEUSER}
    export ADSB_DATABASEPASSWORD1=${DATABASEPASSWORD1}
    export ADSB_DATABASENAME=${DATABASENAME}
elif [ "${DATABASEENGINE}" = "SQLite" ]; then
    if [ -z "${DATABASENAME}" ] ; then
        if [ ! -f ${LIGHTTPD_DOCUMENT_ROOT}/data/portal.sqlite ]; then
            echo -e "\e[94m  Creating an empty SQLite database file...\e[97m"
            sudo touch ${LIGHTTPD_DOCUMENT_ROOT}/data/portal.sqlite
            echo -e "\e[94m  Setting write permissions on the empty SQLite database file...\e[97m"
            sudo chmod 666 ${LIGHTTPD_DOCUMENT_ROOT}/data/portal.sqlite
        fi
        DATABASENAME="${LIGHTTPD_DOCUMENT_ROOT}/data/portal.sqlite"
    fi
    export ADSB_DATABASEENGINE=${DATABASEENGINE}
    export ADSB_DATABASEHOSTNAME=""
    export ADSB_DATABASEUSER=""
    export ADSB_DATABASEPASSWORD1=""
    export ADSB_DATABASENAME=${DATABASENAME}
else
    export ADSB_DATABASEENGINE="xml"
    export ADSB_DATABASEHOSTNAME=""
    export ADSB_DATABASEUSER=""
    export ADSB_DATABASEPASSWORD1=""
    export ADSB_DATABASENAME=""
fi

chmod +x ${RECEIVER_BASH_DIRECTORY}/portal/core.sh
${RECEIVER_BASH_DIRECTORY}/portal/core.sh
if [[ $? -ne 0 ]] ; then
    echo ""
    log_alert_message "THE SCRIPT CORE.SH ENCOUNTERED AN ERROR"
    echo ""
    exit 1
fi


## SETUP ADVANCED PORTAL FEATURES

if [ "${ADVANCED}" = "true" ] ; then
    chmod +x ${RECEIVER_BASH_DIRECTORY}/portal/logging.sh
    ${RECEIVER_BASH_DIRECTORY}/portal/logging.sh
    if [[ $? -ne 0 ]] ; then
        echo ""
        log_alert_message "THE SCRIPT LOGGING.SH ENCOUNTERED AN ERROR"
        echo ""
        exit 1
    fi
fi


## POST INSTALLATION OPERATIONS

unset ADSB_DATABASEENGINE
unset ADSB_DATABASEHOSTNAME
unset ADSB_DATABASEUSER
unset ADSB_DATABASEPASSWORD1
unset ADSB_DATABASENAME

IPADDRESS=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "ADS-B Receiver Project Portal Setup" \
         --msgbox "NOTE THAT PORTAL SETUP IS NOT YET COMPLETE!\n\nIn order to complete the portal setup process visit the following URL in your favorite web browser.\n\nhttp://${IPADDRESS}/install/\n\nFollow the instructions and enter the requested information to complete the ADS-B Receiver Project Portal setup." \
         12 78


## SETUP COMPLETE

log_message "Returning to ${RECEIVER_PROJECT_TITLE} root directory"
cd $RECEIVER_ROOT_DIRECTORY

echo ""
log_title_message "------------------------------------------------------------------------------"
log_title_heading "The ADS-B Portal setup is complete"
echo ""
read -p "Press enter to continue..." discard

exit 0
