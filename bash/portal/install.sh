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
raw_document_root=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
lighttpd_document_root=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $raw_document_root`


## GATHER REQUIRED INFORMATION

log_heading "Gather information required to configure the portal"

log_message "Determining if a portal installation exists"
if [[ -f $lighttpd_document_root/classes/settings.class.php ]]; then
    log_message "An instance of The ADS-B Portal is installed"
    portal_installed="true"
else
    log_message "The ADS-B Portal is not installed"
    portal_installed="false"
fi

if [[ "${portal_installed}" = "true" ]]; then
    log_message "Gathering information needed to proceed with setup"
    database_engine=`grep 'db_driver' $lighttpd_document_root/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    if [[ "${database_engine}" = "xml" ]]; then
        log_message "This is a lite installation of the portal"
        advanced_installation="false"
    else
        log_message "This is an advanced installation of the portal"
        advanced_installation="true"
    fi
    if [[ "${advanced_installation}" = "true" ]]; then
        case "${database_engine}" in
            "mysql")
                log_message "The MySQL database engine is being used"
                database_engine="MySQL"
                ;;
            "sqlite")
                log_message "The SQLite database engine is being used"
                database_engine="SQLite"
                ;;
        esac
        database_hostname=`grep 'db_host' $lighttpd_document_root/classes/settings.class.php | tail -n1 | cut -d\' -f2`
        database_user=`grep 'db_username' $lighttpd_document_root/classes/settings.class.php | tail -n1 | cut -d\' -f2`
        database_password1=`grep 'db_password' $lighttpd_document_root/classes/settings.class.php | tail -n1 | cut -d\' -f2`
        database_name=`grep 'db_database' $lighttpd_document_root/classes/settings.class.php | tail -n1 | cut -d\' -f2`
    fi
else
    log_message "Asking if advanced features should be utilized"
    if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                --title "Portal Type Selection" \
                --defaultno \
                --yesno "NOTE THAT THE ADVANCED FEATURES ARE STILL IN DEVELOPMENT AT THIS TIME\nADVANCED FEATURES SHOULD ONLY BE ENABLED BY DEVELOPERS AND TESTERS ONLY\n\nBy enabling advanced features the portal will log all flights seen as well as the path of the flight. This data is stored in either a MySQL or SQLite database. This will result in a lot more data being stored on your devices hard drive. Keep this and your devices hardware capabilities in mind before selecting to enable these features.\n\nENABLING ADVANCED FEATURES ON DEVICES USING SD CARDS CAN SHORTEN THE LIFE OF THE SD CARD IMMENSELY\n\nDo you wish to enable the portal advanced features?" \
                19 78; then
        log_message "Advanced features will be setup"
        advanced_installation="true"
    else
        log_message "Lite features will be setup"
        advanced_installation="false"
    fi

    if [[ "${advanced_installation}" = "true" ]]; then
        log_message "Asking for the location of the MySQL server"
        database_engine=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                   --title "Choose Database Type" \
                                   --nocancel \
                                   --menu "Choose which database engine to use." 11 80 2 \
                                   "MySQL" "" "SQLite" "" 3>&1 1>&2 2>&3)
        if [[ "${database_engine}" = "MySQL" ]]; then
            if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                        --title "MySQL Database Location" \
                        --yesno "Will the database be hosted locally on this device?" \
                        7 80; then
                log_message "A local MySQL database server will be used"
                local_mysql_server="true"
            else
                log_message "A remote MySQL database server will be used"
            fi

            if [[ "${local_mysql_server}" = "false" ]]; then
                log_message "Asking for the remote MySQL server's hostname"
                database_hostname_title="MySQL Database Server Hostname"
                while [[ -z $database_hostname ]]; do
                    database_hostname=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                 --title "${database_hostname_title}" \
                                                 --nocancel \
                                                 --inputbox "What is the remote MySQL server's hostname?" \
                                                 10 60 3>&1 1>&2 2>&3)
                    database_hostname_title="MySQL Database Server Hostname (REQUIRED)"
                done
                log_message "Asking for the database already exists remotly"
                if whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                            --title "Does MySQL Database Exist" \
                            --yesno "Has the database already been created?" \
                            7 80; then
                    log_message "The database exists on the remote server"
                    database_exists="true"
                else
                    log_message "The database does not exist on the remote server"
                    database_exists="false"
                fi
            fi

            if [[ "${local_mysql_server}" = "true" || "${database_exists}" = "false" ]]; then
                whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                         --title "Create Remote MySQL Database" \
                         --msgbox "This script can attempt to create the MySQL database for you.\nYou will now be asked for the credentials for a MySQL user who has the ability to create a database on the MySQL server." \
                         9 78

                log_message "Asking for the MySQL administrator username"
                database_admin_user_title="MySQL Administrator Username"
                while [[ -z $database_admin_user ]]; do
                    database_admin_user=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                 --title "${database_admin_user_title}" \
                                                 --nocancel \
                                                 --inputbox "Enter the MySQL adminitrator username." \
                                                 8 78 \
                                                 "root" 3>&1 1>&2 2>&3)
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
                log_message "Asking the user to confirm the MySQL administrator password"
                database_admin_password2_title="Confirm The MySQL Administrator Password"
                while [[ -z $database_admin_password2 ]]; do
                    database_admin_password2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                        --title "${database_admin_password2_title}" \
                                                        --nocancel \
                                                        --passwordbox "Confirm the password for the MySQL adminitrator user." \
                                                        8 78 3>&1 1>&2 2>&3)
                    database_admin_password2_title="Confirm The MySQL Administrator Password (REQUIRED)"
                done
                while [[ ! "${database_admin_password1}" = "${database_admin_password2}" ]]; do
                    log_message "The supplied MySQL administrator passwords did not match"
                    database_admin_password1=""
                    database_admin_password2=""
                    whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                             --title "Passwords Did Not Match" \
                             --msgbox "Passwords did not match.\nPlease enter the MySQL administrator password again." \
                             9 78
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
                    log_message "Asking the user to confirm the MySQL administrator password"
                    database_admin_password2_title="Confirm The MySQL Administrator Password"
                    while [[ -z $database_admin_password2 ]]; do
                        database_admin_password2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                            --title "${database_admin_password2_title}" \
                                                            --nocancel \
                                                            --passwordbox "Confirm the password for the MySQL adminitrator user." \
                                                            8 78 3>&1 1>&2 2>&3)
                        database_admin_password2_title="Confirm The MySQL Administrator Password (REQUIRED)"
                    done
                done
            fi

            log_message "Asking for the name of the ADS-B Portal database"
            database_name_title="The ADS-B Portal Database Name"
            while [[ -z $database_name ]]; do
                database_name=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                         --title "${database_name_title}" \
                                         --nocancel \
                                         --inputbox "Enter your ADS-B Receiver Portal database name." \
                                         8 78 3>&1 1>&2 2>&3)
                database_name_title="The ADS-B Portal Database Name (REQUIRED)"
            done

            log_message "Asking for the ADS-B Portal database username"
            database_user_title="The ADS-B Portal Database User"
            while [[ -z $database_user ]]; do
                database_user=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                         --title "${database_user_title}" \
                                         --nocancel \
                                         --inputbox "Enter the user for the ADS-B Receiver Portal database." \
                                         8 78 3>&1 1>&2 2>&3)
                database_user_title="The ADS-B Portal Database User (REQUIRED)"
            done

            log_message "Asking for the ADS-B Portal database password"
            database_password1_title="The ADS-B Portal Database Password"
            while [[ -z $database_password1 ]]; do
                database_password1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                              --title "${database_password1_title}" \
                                              --nocancel \
                                              --passwordbox "Enter the ADS-B Portal database password." \
                                              8 78 3>&1 1>&2 2>&3)
                database_password1_title="The ADS-B Portal Database Password (REQUIRED)"
            done
            log_message "Asking the user to confirm the ADS-B Portal database password"
            database_password2_title="Confirm The ADS-B Portal Database Password"
            while [[ -z database_password2 ]]; do
                database_password2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                              --title "${database_password2_title}" \
                                              --nocancel \
                                              --passwordbox "Confirm the ADS-B Portal database password." \
                                              8 78 3>&1 1>&2 2>&3)
                database_password2_title="Confirm The ADS-B Portal Database Password (REQUIRED)"
            done

            while [[ ! "${database_password1}" = "${database_password2}" ]]; do
                log_message "The supplied ADS-B Portal database passwords did not match"
                database_password1=""
                database_password2=""
                whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                         --title "Passwords Did Not Match" \
                         --msgbox "Passwords did not match.\nPlease enter the ADS-B Portal password again." \
                         9 78
                log_message "Asking for the ADS-B Portal database password"
                database_password1_title="The ADS-B Portal Database Password"
                while [[ -z $database_password1 ]]; do
                    database_password1=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                  --title "${database_password1_title}" \
                                                  --nocancel \
                                                  --passwordbox "Enter the ADS-B Portal database password." \
                                                  8 78 3>&1 1>&2 2>&3)
                    database_password1_title="The ADS-B Portal Database Password (REQUIRED)"
                done
                log_message "Asking the user to confirm the ADS-B Portal database password"
                database_password2_title="Confirm The ADS-B Portal Database Password"
                while [[ -z $database_password2 ]]; do
                    database_password2=$(whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
                                                  --title "${database_password2_title}" \
                                                  --nocancel \
                                                  --passwordbox "Confirm the ADS-B Portal database password." \
                                                  8 78 3>&1 1>&2 2>&3)
                    database_password2_title="Confirm The ADS-B Portal Database Password (REQUIRED)"
                done
            done
        fi
    fi
fi


## INSTALL PREREQUISITE PACAKGES

if [[ "${local_mysql_server}" = "true" ]]; then
    database_exists="false"
    database_hostname="localhost"

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
            echo -e "\e[94m  Creating an empty SQLite database file...\e[97m"
            sudo touch $lighttpd_document_root/data/portal.sqlite
            echo -e "\e[94m  Setting write permissions on the empty SQLite database file...\e[97m"
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

chmod +x ${RECEIVER_BASH_DIRECTORY}/portal/core.sh
${RECEIVER_BASH_DIRECTORY}/portal/core.sh
if [[ $? -ne 0 ]] ; then
    echo ""
    log_alert_message "THE SCRIPT CORE.SH ENCOUNTERED AN ERROR"
    echo ""
    exit 1
fi


## SETUP ADVANCED PORTAL FEATURES

if [ "${advanced_installation}" = "true" ] ; then
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

unset ADSB_PORTAL_DATABASE_ENGINE
unset ADSB_PORTAL_DATABASE_HOSTNAME
unset ADSB_PORTAL_DATABASE_USER
unset ADSB_PORTAL_DATABASE_PASSWORD1
unset ADSB_PORTAL_DATABASE_NAME

ip_address=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`

whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" \
         --title "ADS-B Receiver Project Portal Setup" \
         --msgbox "NOTE THAT PORTAL SETUP IS NOT YET COMPLETE!\n\nIn order to complete the portal setup process visit the following URL in your favorite web browser.\n\nhttp://${ip_address}/install/\n\nFollow the instructions and enter the requested information to complete the ADS-B Receiver Project Portal setup." \
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
