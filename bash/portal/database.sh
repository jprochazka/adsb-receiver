## FUNCTIONS

cancel_setup() {
    echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
    echo -e "  Setup has been halted at the request of the user."
    echo -e ""
    echo -e "\e[93m  ------------------------------------------------------------------------------"
    echo -e "\e[92m  ADS-B Receiver Project Portal setup halted.\e[39m"
    echo -e ""
    exit 1
}

prompt_for_input() {
    if [[ -z $title ]]; then title = "Password"
    if [[ -z $message ]]; then title = "Enter the password."
    while [[ -z $input ]]; do
        input = $(whiptail \
            --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "${title}" \
            --inputbox "${message}" \
            8 78 "${default_value}")
        exit_status = $?
        if [ $exit_status = 0 ]; then
            cancel_setup()
        fi
        title  ="${title} (REQUIRED)"
    done
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
            cancel_setup()
        fi
        title  ="${title} (REQUIRED)"
    done
}

prompt_for_username(){
    if [[ -z $title ]]; then title = "Username"
    if [[ -z $message ]]; then title = "Enter the username."
    while [[ -z $user ]]; do
        user = $(whiptail \
            --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "${title}" \
            --inputbox "${message}" \
            8 78)
        exit_status = $?
        if [ $exit_status = 0 ]; then
            cancel_setup()
        fi
        title = "${title} (REQUIRED)"
    done
}


## MYSQL

setup_mysql() {
    # Gather information
    mysql_host = "localhost"
    database_exists = false
    if [[ "${PORTAL_LOCAL_MYSQL_SERVER}" = "false" ]]
        mysql_host = $(whiptail \
            --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "MySQL Database Server Hostname" \
            --nocancel \
            --inputbox "\nWhat is the remote MySQL server's hostname?" \
            10 60)

        database_exists = $(whiptail \
            --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "Does MySQL Database Exist" \
            --yesno "Does the database already exist on the host?" \
            7 80)
    if

    # Check for and install if needed all MariaDB packages needed to host the database locally
    if [[ "${mysql_host}" = "localhost" || "${mysql_host}" = "127.0.0.1" ]]
        CheckPackage mariadb-server
        CheckPackage mariadb-client
    fi

    whiptail \
        --backtitle "${RECEIVER_PROJECT_TITLE}" \
        --title "MySQL Secure Installation" \
        --msgbox "The mysql_secure_installation will now be executed. Follow the on screen instructions to complete the MariaDB (MySQL) server setup." \
        12 78

    echo -e "\e[94m  Executing the mysql_secure_installation script...\e[97m"
    sudo mysql_secure_installation
    echo ""

    # Get MySQL administrative user credentials
    if [[ "${mysql_host}" = "localhost" || "${database_exists}" = "false" ]] ; then
        whiptail \
            --backtitle "${RECEIVER_PROJECT_TITLE}" \
            --title "Create Remote MySQL Database" \
            --msgbox "This script will attempt to create the MySQL database for you.\nPlease supply credentials for the root user or another account granted permission to create a new database." \
            9 78

        title = "MySQL Administrative Username"
        message = "Enter the MySQL administrator username"
        default_value = "root"
        prompt_for_input()
        admin_user = $input

        title = "MySQL Administrator Password"
        message = "Enter the MySQL password for username ${admin_user}"
        prompt_for_password()
        admin_password_one = $password

        title = "Confirm The MySQL Administrator Password"
        message = "Reenter the MySQL password for username ${admin_user}"
        prompt_for_password()
        admin_password_two = $password

        while [[ ! $admin_password_one = $admin_password_two ]] ; do
            admin_password_one=""
            admin_password_two=""

            title = "MySQL Administrator Passwords Did Not Match"
            message = "Enter the MySQL password for username ${admin_user}"
            prompt_for_password()
            admin_password_one = $password

            title = "Confirm The MySQL Administrator Password"
            message = "Reenter the MySQL password for username ${admin_user}"
            prompt_for_password()
            admin_password_two = $password
        done
    fi

    # Get MySQL database name and database user credentials
    title = "MySQL Database Name"
    message = "Enter the name of the database to be used"
    if [[ "${database_exists}" = "false" ]] ; then
        message = "Enter the name of the database to be created"
    fi
    default_value = "adsbportal"
    prompt_for_input()
    database_name = $input

    title = "MySQL Database Username"
    message = "Enter the username associated with the database ${database_name}"
    if [[ "${database_exists}" = "false" ]] ; then
        message = "Enter the username to be added to the database ${database_name}"
    fi
    default_value = "adsbuser"
    prompt_for_input()
    database_username = $input

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


## POSTGRESQL

## SQLITE