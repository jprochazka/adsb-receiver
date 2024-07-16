## FUNCTIONS

cancel_setup() {
    LogAlertHeading "INSTALLATION HALTED"

    LogAlertMessage "Setup has been halted due to error reported by the mysql.sh script"
    if [[ "${cancel_initiated_by_user}" == "true" ]]
        LogAlertMessage "Setup has been halted at the request of the user"
    fi
    echo ""
    LogTitleMessage "------------------------------------------------------------------------------"
    LogTitleHeading "ADS-B Portal setup has been halted"
    exit 1
}

prompt_for_input() {
    if [[ -z $title ]]; then title = "Input"
    if [[ -z $message ]]; then title = "Enter input."
    while [[ -z $input ]]; do
        input = $(whiptail \
            --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "${title}" \
            --inputbox "${message}" \
            8 78 "${default_value}")
        exit_status = $?
        if [ $exit_status = 0 ]; then
            cancel_initiated_by_user = "true"
            cancel_setup()
        fi
        title  ="${title} (REQUIRED)"
    done
    default_value = ""
}

prompt_for_password() {
    if [[ -z $title ]]; then title = "Password"
    if [[ -z $message ]]; then title = "Enter the password."
    while [[ -z $password ]]; do
        password = $(whiptail \
            --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "${title}" \
            --passwordbox "${message}" \
            8 78)
        exit_status = $?
        if [ $exit_status = 0 ]; then
            cancel_initiated_by_user = "true"
            cancel_setup()
        fi
        title  ="${title} (REQUIRED)"
    done
}

## MYSQL SETUP

# Start here
mysql_setup() {
    setup_mariadb()
    get_mysql_admin_credentials()
    get_mysql_database_credentials()
    create_mysql_database()
    create_mysql_user()
}

# Setup MariaDB server if the database is going to be hosted locally
setup_mariadb() {
    LogHeading "MariaDB Setup"
    if ! whiptail --backtitle "${RECEIVER_PROJECT_TITLE}" --title "ADS-B Portal Database Location" --defaultyes --yesno "Will the ADS-B Portal database be hosted locally?" 10 60; then
        LogHeading "Local MariaDB server setup will be skipped"

        LogMessage "Requesting the remote MySQL server's hostname"
        title = "MySQL Database Server Hostname"
        message = "What is the remote MySQL server's hostname?"
        default_value = ""
        prompt_for_input()
        database_host = $input
        LogMessage "Setting MySQL server hostname to ${database_host}"

        return
    fi
    LogHeading "Begining MariaDB server setup"
    
    LogMessage "Installing MariaDB server if not already installed"
    CheckPackage mariadb-server

    whiptail \
        --backtitle "${RECEIVER_PROJECT_TITLE}" \
        --title "Excecuting mysql_secure_installation" \
        --msgbox "The mysql_secure_installation will now be executed.\nFollow the on screen instructions to complete the MariaDB (MySQL) server setup." \
        12 78

    LogMessage "Executing the mysql_secure_installation script"
    echo ""
    sudo mysql_secure_installation
    echo ""

    database_host = "localhost"
    LogMessage "Setting MySQL server hostname to ${database_host}"

    LogMessage "Local MariaDB server setup complete"
}

# Request MySQL administrator credentials
get_mysql_admin_credentials() {
    LogHeading "Requesting MySQL administrative credentials"

    admin_user = ""
    admin_password_one = ""
    admin_password_two = ""

    LogMessage "Requesting MySQL administrative user"
    title = "MySQL Administrative User"
    message = "Enter the MySQL administrator user"
    default_value = "root"
    prompt_for_input()
    admin_user = $input

    LogMessage "Requesting MySQL administrative password from the user"
    title = "MySQL Administrator Password"
    message = "Enter the MySQL password for user ${admin_user}"
    prompt_for_password()
    admin_password_one = $password

    title = "Confirm The MySQL Administrator Password"
    message = "Reenter the MySQL password for user ${admin_user}"
    prompt_for_password()
    admin_password_two = $password

    while [[ ! $admin_password_one = $admin_password_two ]] ; do
        admin_password_one=""
        admin_password_two=""

        title = "MySQL Administrator Passwords Did Not Match"
        message = "Enter the MySQL password for user ${admin_user}"
        prompt_for_password()
        admin_password_one = $password

        title = "Confirm The MySQL Administrator Password"
        message = "Reenter the MySQL password for user ${admin_user}"
        prompt_for_password()
        admin_password_two = $password
    done

    LogMessage "Installing MariaDB client if not already installed"
    CheckPackage mariadb-client

    LogMessage "Attempting to log into the MySQL server using admininstrative credentials"
    while ! sudo mysql -u $admin_user -p $admin_password_one -h $mysql_host -e ";" ; do
        LogMessage "Unable to log into the MySQL server using admininstrative credentials"
        whiptail \
            --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "Unable To Log Into MySQL Server" \
            --msgbox "Unable to log into the MySQL server using the supplied credentials.\nYou will now be prompted to reenter the administrative user credentials." \
            12 78

        get_mysql_admin_credentials()
    done
    LogMessage "Successfully logged into the MySQL server using admininstrative credentials"
}

# Request MySQL database credentials
get_mysql_database_credentials() {
    LogHeading "Requesting MySQL database credentials"

    LogMessage "Requesting MySQL database user"
    title = "MySQL Database Username"
    message = "Enter the username associated with the database ${database_name}"
    if [[ "${database_exists}" = "false" ]] ; then
        message = "Enter the username to be added to the database ${database_name}"
    fi
    default_value = "adsbuser"
    prompt_for_input()
    database_username = $input

    LogMessage "Requesting MySQL database password from the user"
    title = "Database Password"
    message = "Enter the password assigned to the username ${database_username}"
    prompt_for_password()
    database_password_one = $password

    title = "Confirm The Database Password"
    message = "Reenter the password assigned to username ${database_username}"
    prompt_for_password()
    database_password_two = $password

    while [[ ! $database_password_one = $database_password_two ]] ; do
        database_password_one=""
        database_password_two=""

        title = "Database Username Passwords Did Not Match"
        message = "Enter the password assigned to the username ${database_username}"
        prompt_for_password()
        database_password_one = $password

        title = "Confirm The Database Username Password"
        message = "Reenter the password assigned to the username ${database_username}"
        prompt_for_password()
        database_password_two = $password
    done
}

# Create the MySQL database if present
create_mysql_database() {
    LogHeading "Create the ADS-B Portal MySQL database if it does not exist"

    LogMessage "Asking the user for the name of the database to use"
    title = "MySQL Database Name"
    message = "Enter the name of the database to use"
    default_value = "adsbportal"
    prompt_for_input()
    database_name = $input

    LogMessage "Checking if MySQL database ${database_name} exists"
    if mysql -u $admin_user -p $admin_password_one -h $mysql_host -e "USE ${database_name}"; then
        LogMessage "Database ${database_name} exists"
        return
    fi
    
    LogMessage "Creating MySQL database ${database_name}"
    if ! mysql -u $admin_user -p $admin_password_one -h $mysql_host -e "CREATE DATABASE USE ${database_name}"; then
        LogMessage "Creation of MySQL database ${database_name} failed"
        cancel_setup()
    fi
    LogMessage "MySQL database ${database_name} was created successfully"
}

# Create the MySQL user if not present
create_mysql_user() {
    LogHeading "Create the ADS-B Portal MySQL database user if it does not exist"

    LogMessage "Checking if MySQL database user ${database_user} exists"
    if mysql -u $admin_user -p $admin_password_one -h $mysql_host -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '${database_user}')"; then
        LogMessage "MySQL database user ${database_user} exists"

        # TODO: CHECK PRIVILEGES
        LogMessage "Checking MySQL permissions for database user ${database_user} on MySQL database name ${database_name}"
        user_grants = `mysql $admin_user -p $admin_password_one -h $mysql_host -e "show grants for '${user}'@'localhost';"`
        if [[ $user_grants != *'GRANT ALL PRIVILEGES ON `adsbportal`.*'* ]]; then
            LogWarningMessage "Privileges may not be set properly for user ${database_user} on host ${mysql_host}"
        fi
        if [[ $user_grants == *'`adsbuser`@`localhost`'* ]]; then
            LogWarningMessage "Privileges are set only for localhost for user ${database_user} on host ${mysql_host}"
        fi

        Return
    fi

    LogMessage "Creating MySQL database user ${database_user}"
    query = "CREATE USER '${database_user}'@'%' IDENTIFIED BY '${database_password}'"
    if [[ "${mysql_host}" == "localhost" ]]
        query = "CREATE USER '${database_user}'@'${$mysql_host}' IDENTIFIED BY '${database_password}'"
    fi
    if ! mysql -u $admin_user -p $admin_password_one -h $mysql_host -e $query; then
        LogMessage "Creation of MySQL database user ${database_name} failed"
        cancel_setup()
    fi
    LogMessage "MySQL database user ${database_user} was created successfully"

    LogMessage "Setting permission for database user ${database_user} on database ${database_name}"
    query = "GRANT ALL PRIVILEGES ON ${database_name}.* TO '${database_user}'@'%'"
    if [[ "${mysql_host}" == "localhost" ]]
        query = "GRANT ALL PRIVILEGES ON ${database_name}.* TO '${database_user}'@'localhost'"
    fi
    if ! mysql -u $admin_user -p $admin_password_one -h $mysql_host -e $query; then
        LogMessage "Failed to set permission on MySQL database ${database_name} for MySQL user ${database_user}"
        cancel_setup()
    fi
    LogMessage "Permissions set on MySQL database ${database_name} for MySQL user ${database_user}"

    LogMessage "Flushing priviledges on the MySQL database server ${mysql_host}"
    if ! mysql -u $admin_user -p $admin_password_one -h $mysql_host -e "FLUSH PRIVILEGES"; then
        LogMessage "Failed to flushing priviledges on the MySQL database server ${mysql_host}"
        cancel_setup()
    fi
    LogMessage "Successfully flushed priviledges on the MySQL database server ${mysql_host}"
}

modify_api_config() {
    
}