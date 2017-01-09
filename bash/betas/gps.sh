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
# Copyright (c) 2016-2017, Joseph A. Prochazka & Romeo Golf                         #
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

#################################################################################
# Display Done/Error based on return code of last action.

function Check_Return_Code () {
    LINE=$((`stty size | awk '{print $1}'` - 1))
    COL=$((`stty size | awk '{print $2}'` - 8))
    tput cup "${LINE}" "${COL}"
    if [[ $? -eq 0 ]] ; then
        echo -e "\e[97m[\e[32mDone\e[97m]\e[39m\n"
    else
        echo -e "\e[97m[\e[31mError\e[97m]\e[39m\n"
        echo -e "\e[39m  ${ACTION}\n"
        false
    fi
}

#################################################################################
# Apt install function.

function CheckPackage () {
    if [[ -n $1 ]] ; then
        ACTION=$(sudo apt-get install -y $1 2>&1)
    fi
}

#################################################################################
# Apt remove function.

function Apt_Remove () {
    if [[ -n $1 ]] ; then
        ACTION=$(sudo apt remove $1 2>&1)
    fi
}

#################################################################################
# Apt remove function.

function Apt_Hold () {
    if [[ -n $1 ]] ; then
        ACTION=$(sudo apt-mark hold $1 2>&1)
    fi
}

#################################################################################
# Start a system service.

function Service_Start () {
    if [[ -n $1 ]] ; then
        SERVICE_STATUS=$(sudo systemctl status $1 2>&1)
        if [[ `echo ${SERVICE_STATUS} | egrep "Active:" | egrep -c ": active"` -eq 0 ]] ; then
            echo -en "  Starting service \"$1\"..."
            ACTION=$(sudo systemctl start $1 2>&1)
        elif [[ `echo ${SERVICE_STATUS} | egrep "Active:" | egrep -c ": active"` -gt 0 ]] ; then
            echo -en "  Restarting service \"$1\"..."
            ACTION=$(sudo systemctl restart $1 2>&1)
        else
            echo -en "  Error: unable to start service \"$1\"..."
            false
        fi
        unset SERVICE_STATUS
    else
        echo -en "  Error: no service provided..."
    fi
}

#################################################################################
# Stop a system service.

function Service_Stop () {
    if [[ -n $1 ]] ; then
        SERVICE_STATUS=$(sudo systemctl status $1 2>&1)
        if [[ `echo ${SERVICE_STATUS} | egrep "Active:" | egrep -c ": active"` -gt 0 ]] ; then
            echo -en "  Stopping service \"$1\"..."
            ACTION=$(sudo systemctl stop $1 2>&1)
        elif [[ `echo ${SERVICE_STATUS} | egrep "Active:" | egrep -c ": inactive"` -gt 0 ]] ; then
            # echo -en "  Service \"$1\" already stopped..."
            true
        else
            echo -en "  Error: unable to stop service \"$1\"..."
            false
        fi
        unset SERVICE_STATUS
    else
        echo -en "  Error: no service provided..."
    fi
}

#################################################################################
# Enable a system service.

function Service_Enable () {
    if [[ -n $1 ]] ; then
        SERVICE_STATUS=$(sudo systemctl status $1 2>&1)
        if [[ `echo ${SERVICE_STATUS} | egrep "Loaded:" | egrep -c "; enabled"` -eq 0 ]] ; then
            echo -en "  Enabling service \"$1\"..."
            ACTION=$(sudo systemctl enable $1 2>&1)
        elif [[ `echo ${SERVICE_STATUS} | egrep "Loaded:" | egrep -c "; enabled"` -gt 0 ]] ; then
            #echo -en "  Service \"$1\" already enabled..."
            true
        else
            echo -en "  Error: unable to enable service \"$1\"..."
            false
        fi
        unset SERVICE_STATUS
    else
        echo -en "  Error: no service provided..."
        false
    fi
}

#################################################################################
# Disable a system service.

function Service_Disable () {
    if [[ -n $1 ]] ; then
        SERVICE_STATUS=$(sudo systemctl status $1 2>&1)
        if [[ `echo ${SERVICE_STATUS} | egrep "Loaded:" | egrep -c "; enabled"` -gt 0 ]] ; then
            echo -en "  Disabling service \"$1\"..."
            ACTION=$(sudo systemctl disable $1 2>&1)
        elif [[ `echo ${SERVICE_STATUS} | egrep "Loaded:" | egrep -c "; disabled"` -gt 0 ]] ; then
            #echo -en "  Service \"$1\" already disabled..."
            true
        else
            echo -en "  Error: unable to disable service \"$1\"..."
            false
        fi
        unset SERVICE_STATUS
    else
        echo -en "  Error: no service provided..."
        false
    fi
}

#################################################################################
# Detect CPU Architecture.

function Check_CPU () {
    if [[ -z ${CPU_ARCHITECTURE} ]] ; then
        echo -en "\e[33m  Detecting CPU architecture...\e[97m"
        CPU_ARCHITECTURE=`uname -m | tr -d "\n\r"`
    fi
}

#################################################################################
# Detect Platform.

function Check_Platform () {
    if [[ `egrep -c "^Hardware.*: BCM" /proc/cpuinfo` -gt 0 ]] ; then
        HARDWARE_PLATFORM="RPI"
    elif [[ `egrep -c "^Hardware.*: Allwinner sun4i/sun5i Families$" /proc/cpuinfo` -gt 0 ]] ; then
        HARDWARE_PLATFORM="CHIP"
    else
        HARDWARE_PLATFORM="unknown"
    fi
}

#################################################################################
# Detect Hardware Revision.

function Check_Hardware () {
    if [[ -z ${HARDWARE_REVISION} ]] ; then
        echo -en "\e[33m  Detecting Hardware revision...\e[97m"
        HARDWARE_REVISION=`grep "^Revision" /proc/cpuinfo | awk '{print $3}'`
    fi
}

#################################################################################
# Enable serial port on RPi.

function Enable_Serial () {
    if [[ `egrep -c "enable_uart=" ${BOOT_CONFIG}` -eq 0 ]] ; then
        echo -en "  Enabling serial port..."
        if [[ `tail -n1 ${BOOT_CONFIG} | egrep -c "[a-z0-9#]"` -gt 0 ]] ; then
            ACTION=$(echo -en "\n" | tee -a ${BOOT_CONFIG})
        fi
        ACTION=$(echo -en "# Enable UART on RPi3\nenable_uart=1\n\n" | tee -a ${BOOT_CONFIG})
    elif [[ `egrep -c "enable_uart=0" ${BOOT_CONFIG}` -eq 1 ]] ; then
        echo -en "  Enabling serial port..."
        ACTION=$(sudo sed -i -e 's/enable_uart=0/enable_uart=1/g' ${BOOT_CONFIG} 2>&1)
    elif [[ `egrep -c "enable_uart=1" ${BOOT_CONFIG}` -eq 1 ]] ; then
        echo -en "  The serial port is already enabled..."
    fi
}

#################################################################################
# Disable Bluetooth on RPi3.

function Disable_Bluetooth () {
    if [[ `egrep -c "(dtoverlay=pi3-disable-bt|dtoverlay=pi3-miniuart-bt)" ${BOOT_CONFIG}` -eq 0 ]] ; then
        echo -en "  Disabling Bluetooth on RPi3..."
        if [[ `tail -n1 ${BOOT_CONFIG} | egrep -c "[a-z0-9#]"` -gt 0 ]] ; then
            ACTION=$(echo -en "\n" | tee -a ${BOOT_CONFIG})
        fi
        ACTION=$(echo -en "# Disabling Bluetooth on RPi3\ndtoverlay=pi3-disable-bt\n\n" | tee -a ${BOOT_CONFIG})
        REBOOT_REQUIRED="true"
    elif [[ `egrep -c "dtoverlay=pi3-disable-bt" ${BOOT_CONFIG}` -gt 0 ]] ; then
        echo -en "  Verifying that Bluetooth is disabled..."
    elif [[ `egrep -c "dtoverlay=pi3-miniuart-bt" ${BOOT_CONFIG}` -gt 0 ]] ; then
        echo -en "  Verifying that Bluetooth was moved to software serial port..."
    fi
}

#################################################################################
# Enable RPi GPIO pin for PPS signal input.

function Enable_PPS () {
    if [[ `egrep -c "dtoverlay=pps-gpio,gpiopin" ${BOOT_CONFIG}` -eq 0 ]] ; then
        echo -en "  Enabling GPS PPS from GPIO pin \"${GPS_PPS_PIN}\"..."
        if [[ `tail -n1 ${BOOT_CONFIG} | egrep -c "[a-z0-9#]"` -gt 0 ]] ; then
            ACTION=$(echo -en "\n" | tee -a ${BOOT_CONFIG})
        fi
        ACTION=$(echo -en "# Enable GPS PPS from GPIO pin ${GPS_PPS_PIN}.\ndtoverlay=pps-gpio,gpiopin=${GPS_PPS_PIN}\n\n" | tee -a ${BOOT_CONFIG})
        REBOOT_REQUIRED="true"
    else
        GPS_PPS_CONFIGURED_PIN=`egrep "dtoverlay=pps-gpio,gpiopin" ${BOOT_CONFIG} | awk -F "=" '{print $3}'`
        echo -en "  GPS PPS already enabled from GPIO pin ${GPS_PPS_CONFIGURED_PIN}..."
    fi
}

#################################################################################
# Check for GPS signals on tty.

function Check_GPS_TTY () {
    if [[ `echo ${GPS_TTY_DEV} | egrep -c "tty"` -gt 0 ]] ; then
        echo -en "  Testing for GPS signal from \"${GPS_TTY_DEV}\"..."
        GPS_TTY_TEST=`timelimit -q -t 3 cat /dev/${GPS_TTY_DEV} 2>&1`
        if [[ `echo "${GPS_TTY_TEST}" | egrep -c "GP(GGA|GLL|GSA|GSV|RMC|VTG)"` -gt 0 ]] ; then
            echo -en "  Success..."
        elif [[ -z "${GPS_TTY_TEST}" ]] ; then
            echo -en "  Error: no data returned by device \"/dev/${GPS_TTY_DEV}\"..."
            false
        else
            echo -en "  Error: no signal detected..."
            false
        fi
    else
        echo -en "  Error: GPS device not found at \"/dev/${GPS_TTY_DEV}\"..."
        false
    fi
}

#################################################################################
# Check for PPS signals.

function Check_GPS_PPS () {
    if [[ `echo ${GPS_PPS_DEV} | egrep -c "pps"` -gt 0 ]] ; then
        echo -en "  Testing for GPS PPS pulses from \"${GPS_PPS_DEV}\"..."
        GPS_PPS_TEST=`timelimit -q -t 3 ppstest /dev/${GPS_PPS_DEV} 2>&1`
        if [[ `echo "${GPS_PPS_TEST}" | egrep -c ", sequence: [0-9]* - clear  [0-9]\."` -gt 0 ]] ; then
            echo -en "  Success..."
        elif [[ `echo "${GPS_PPS_TEST}" | egrep -c "unable to open"` -gt 0 ]] ; then
            echo -en "  Error: no data returned by device \"/dev/${GPS_PPS_DEV}\"..."
            false
        else
            echo -en "  Failed, no signal detected..."
            false
        fi
    else
        echo -en "  Error: PPS device not found at \"/dev/${GPS_PPS_DEV}\"..."
        false
    fi
}

#################################################################################
# Create UDEV Symlink.

function Create_UDEV_Symlink () {
    if [[ ! -f ${GPS_SYMLINK_RULE} ]] ; then
        echo -en "  Creating device symlinks..."
        ACTION=$(echo -en "KERNEL==\"${GPS_TTY_DEV}\", SYMLINK+=\"gps0\"\nKERNEL==\"${GPS_PPS_DEV}\", OWNER=\"root\", GROUP=\"tty\", MODE=\"0660\", SYMLINK+=\"gpspps0\"\n" | tee ${GPS_SYMLINK_RULE})
        ACTION=$(sudo udevadm trigger 2>&1)
    fi
}

#################################################################################
# Configure GPS service.

function Configure_Service_GPS () {
    if [[ -f "${GPS_SERVICE_CONFIG}" ]] ; then
        KEYPAIRS="START_DAEMON=true USBAUTO=false DEVICES=/dev/gps0 GPSD_OPTIONS=-n GPSD_SOCKET=/var/run/gpsd.sock"
        for KEYPAIR in ${KEYPAIRS} ; do
            KEY=`echo -E "${KEYPAIR}" | gawk -F "=" '{print $1}'`
            VALUE=`echo -E "${KEYPAIR}" | gawk -F "=" '{print $2}'`
            VALUE_ESCAPED=`echo -E "${KEYPAIR}" | gawk -F "=" '{print $2}'| sed -e 's/\\//\\\\\//g'`
            if [[ `grep -c "^${KEY}" ${GPS_SERVICE_CONFIG}` -eq 0 ]] ; then
                if [[ `tail -n1 ${GPS_SERVICE_CONFIG} | egrep -c "[a-z0-9#]"` -gt 0 ]] ; then
                    ACTION=$(echo -en "\n" | tee -a ${GPS_SERVICE_CONFIG})
                fi
                ACTION=$(echo -en "\n# Added by GPS setup.\n${KEY}=\"${VALUE}\"\n\n" | tee -a ${GPS_SERVICE_CONFIG})
            else
                CURRENT_VALUE=`egrep "^${KEY} *= *\"" ${GPS_SERVICE_CONFIG} | awk -F "=" '{print $2}' | sed -e 's/"//g' -e 's/^ //g'`
                if [[ ! "${CURRENT_VALUE}" = "${VALUE}" ]] ; then
                    if [[ -n "${VALUE}" ]] ; then
                        ACTION=$(sudo sed -i -e "s/^\(${KEY} *= *\).*/\1\"${VALUE_ESCAPED}\"/" ${GPS_SERVICE_CONFIG} 2>&1)
                    fi
                fi
            fi
            unset KEY
            unset VALUE
        done
    fi
}

#################################################################################
# Remove DHCP hooks.

function Remove_DHCP_Hooks () {
    if [[ -f "${NTP_DHCP_HOOK}" ]] || [[ -f "${NTP_DHCP_FILES}" ]] ; then
        echo -en "  Prevening DHCP from updating NTP config..."
        ACTION=$(sudo rm -v ${NTP_DHCP_HOOK} ${NTP_DHCP_FILE} 2>&1)
    fi
}

#################################################################################
# Check if a directory exists, if not create it.
function Make_Dir () {
    # Requires: a directory
    if [[ -n "$1" ]] ; then
        if [[ ! -d "$1" ]] ; then
            echo -en "  Creating build directory \"$1\"..."
            ACTION=$(mkdir -v $1)
        else
            echo -en "  Build directory \"$1\" already exists..."
        fi
    else
        false
    fi
}

#################################################################################
# Download latetest source.
function Download_Source_NTP () {
    # Requires: ${NTP_SOURCE_DIR} ${NTP_SOURCE_FILE} ${NTP_SOURCE_URL}
    if [[ -n "${NTP_SOURCE_DIR}" ]] && [[ -n "${NTP_SOURCE_FILE}" ]] && [[ -n "${NTP_SOURCE_URL}" ]] ; then
        ACTION=$(curl -s -L "${NTP_SOURCE_URL}" -o "${NTP_SOURCE_DIR}/${NTP_SOURCE_FILE}")
        if [[ -f "${NTP_SOURCE_DIR}/${NTP_SOURCE_FILE}" ]] ; then
            echo -en  "Source file \"${NTP_SOURCE_FILE}\" downloaded sucessfully..."
        else
            echo -en "  Error: Unable to download source..."
            false
        fi
    else
        echo -en "  Error: Unable to download source..."
        false
    fi
}

#################################################################################
# Verify MD5 of source.
function Verify_Source_NTP () {
    # Requires: ${NTP_SOURCE_DIR} ${NTP_SOURCE_FILE} ${NTP_SOURCE_MD5}
    if [[ -f "${NTP_SOURCE_DIR}/${NTP_SOURCE_FILE}" ]] ; then
         if [[ -n "${NTP_SOURCE_MD5}" ]] ; then
             if [[ `md5sum "${NTP_SOURCE_DIR}/${NTP_SOURCE_FILE}" | awk '{print $1}'` = ${NTP_SOURCE_MD5} ]] ; then
                 echo -en "  MD5 checksum verified for \"${NTP_SOURCE_FILE}\"..."
             else
                 echo -en "  Error: MD5 mismatch..."
                 false
             fi
        else
            echo -en "  Error: no MD5 supplied..."
            false
        fi
    else
        echo -en "  Error: Unable to access local file \"${NTP_SOURCE_DIR}/${NTP_SOURCE_FILE}\"...."
        false
    fi
}

#################################################################################
# Unpack source.
function Unpack_Source_NTP () {
    # Requires: ${NTP_SOURCE_DIR} ${NTP_SOURCE_FILE} ${NTP_SOURCE_VERSION}
    if [[ -f "${NTP_SOURCE_DIR}/${NTP_SOURCE_FILE}" ]] ; then
        ACTION=$(tar -vxzf "${NTP_SOURCE_DIR}/${NTP_SOURCE_FILE}" -C "${NTP_SOURCE_DIR}")
        if [[ -d "${NTP_SOURCE_DIR}/${NTP_SOURCE_VERSION}" ]] ; then
            echo -en "  Successfully extracted \"${NTP_SOURCE_FILE}\" to \"${NTP_SOURCE_DIR}\"..."
        else
             echo -en "  Error: Unable to extract \"${NTP_SOURCE_FILE}\" to \"${NTP_SOURCE_DIR}\"..."
             false
        fi
    else
        echo -en "  Error: Unable to extract \"${NTP_SOURCE_FILE}\" to \"${NTP_SOURCE_DIR}\"..."
        false
    fi

}

#################################################################################
# Compile source.
function Compile_Source_NTP () {
    # Requires: ${NTP_SOURCE_DIR} ${NTP_SOURCE_VERSION} ${NTP_SOURCE_CFLAGS}
    if [[ -d "${NTP_SOURCE_DIR}/${NTP_SOURCE_VERSION}" ]] ; then
        echo -en "  Compiling \"${NTP_SOURCE_VERSION}\" from source..."
        cd "${NTP_SOURCE_DIR}/${NTP_SOURCE_VERSION}"
        if [[ `ls -l *.h 2>/dev/null | grep -c "\.h"` -gt 0 ]] ; then
            ACTION=$(sudo make -C "${NTP_SOURCE_DIR}/${NTP_SOURCE_VERSION}" clean 2>&1)
        fi
        if [[ -x "configure" ]] ; then
            ACTION=$(./configure ${NTP_SOURCE_CFLAGS} 2>&1)
        fi
        if [[ -f "Makefile" ]] ; then
            ACTION=$(make -C "${NTP_SOURCE_DIR}/${NTP_SOURCE_VERSION}" 2>&1)
        fi
        if [[ `grep -c "^install:" Makefile` -gt 0 ]] ; then
            ACTION=$(sudo make -C "${NTP_SOURCE_DIR}/${NTP_SOURCE_VERSION}" install 2>&1)
        fi
    else
        echo -en "  Error: build directory not found"
        false
    fi
}


### VARIABLES

PACKAGES="gpsd gpsd-clients libcap-dev libssl-dev ntpdate pps-tools python-gps texinfo timelimit"
SERVICES_DISABLE="hciuart serial-getty@ttyAMA0.service serial-getty@ttyS0.service ntp.service gpsd.socket gpsd.service"
SERVICES_ENABLE="gpsd.service ntp.service"
BOOT_CONFIG="/boot/config.txt"
GPS_TTY_DEV="ttyAMA0"
GPS_PPS_DEV="pps0"
GPS_SYMLINK_RULE="/etc/udev/rules.d/10-pps.rules"
GPS_SERVICE_CONFIG="/etc/default/gpsd"
NTP_DHCP_HOOK="/lib/dhcpcd/dhcpcd-hooks/50-ntp.conf"
NTP_DHCP_FILE="/var/lib/ntp/ntp.conf.dhcp"

### START CONFIGURATION

echo -en "\n\e[1m  Installing GPS based NTP time server\e[0m\n\n\n"

### INSTALL PACKAGES

for PACKAGE in ${PACKAGES} ; do
    echo -en "  Installing package ${PACKAGE}..."
    CheckPackage ${PACKAGE}
    Check_Return_Code
done

### DISABLE SERVICES

for SERVICE in ${SERVICES_DISABLE} ; do
    echo -en "  Disabling service ${SERVICE}..."
    Service_Stop ${SERVICE}
    Service_Disable ${SERVICE}
    Check_Return_Code
done

### ENABLE SERIAL PORTS

Enable_Serial 
Check_Return_Code

### DISABLE BLUETOOTH

Check_Hardware
Check_Return_Code

if [[ -n "${HARDWARE_REVISION}" ]] ; then
    # Swap serial ports on Raspberry Pi 3.
    if [[ "${HARDWARE_REVISION}" = "a02082" ]] || [[ "${HARDWARE_REVISION}" = "a22082" ]] ; then
        Disable_Bluetooth
        Check_Return_Code
    fi
fi

### CONFIGURE PPS

Enable_PPS
Check_Return_Code

### TEST GPS AND PPS SIGNALS

if [[ "${REBOOT_REQUIRED}" = "true" ]] ; then
    echo -en "\n\e[1m  A Reboot will be required before GPS and PPS signals can be tested! \e[0m"
else
    if [[ -n "${GPS_TTY_DEV}" ]] && [[ -n "${GPS_PPS_DEV}" ]] ; then 
        # Check GPS signal.
        Check_GPS_TTY
        Check_Return_Code
        # And PPS signal.
        Check_GPS_PPS
        Check_Return_Code
    elif [[ -n "${GPS_TTY_DEV}" ]] ; then
        # Otherwise test GPS signal.
        Check_GPS_TTY
        Check_Return_Code
    else
       echo -en "  Unable to run GPS or PPS signal tests..."
    fi
fi

### CREATE SYMLINKS TO GPS AND PPS DEVICES

Create_UDEV_Symlink
Check_Return_Code

### GPSD SERVICE

Configure_Service_GPS
Check_Return_Code
 
### PREVENT DHCP FROM UPDATING NTP CONFIG

Remove_DHCP_Hooks
Check_Return_Code

### INSTALL NTP WITH PPS SUPPORT

NTP_SOURCE_DIR="${PWD}/build/ntp"
NTP_SOURCE_RSS="http://support.ntp.org/rss/releases.xml"
NTP_SOURCE_URL=`curl -s -L "${NTP_SOURCE_RSS}" -o - | grep -A1 "Stable</tit" | grep "<link>" | sed -e 's/<link>//g' -e 's/<\/link>//g' -e 's/\ //g'`
NTP_SOURCE_FILE=`echo ${NTP_SOURCE_URL} | awk -F "/" '{print $NF}'`
NTP_SOURCE_VERSION=`echo ${NTP_SOURCE_FILE} | sed -e 's/.tar.gz//g'`
NTP_SOURCE_MD5=`curl -s -L "${NTP_SOURCE_URL}.md5" -o - |grep "${NTP_SOURCE_FILE}" | awk '{print $1}'`
NTP_SOURCE_CFLAGS=" --enable-all-clocks --enable-parse-clocks --disable-local-libopts --enable-step-slew --without-ntpsnmpd --enable-linuxcaps --prefix=/usr"
MAKE_CFLAGS="-j4"

# Remove system package.
Apt_Remove ntp
Check_Return_Code

# Prevent it from being reinstalled.
Apt_Hold ntp
Check_Return_Code

# Make build directory.
Make_Dir ${NTP_SOURCE_DIR}
Check_Return_Code

# Check if existing source exits and matches expected MD5, if not then download.
until (Verify_Source_NTP && Check_Return_Code) ; do
    Download_Source_NTP
    Check_Return_Code
    sleep 5
done

# Unpack source.
Unpack_Source_NTP
Check_Return_Code

# Compile soure.
Compile_Source_NTP
Check_Return_Code

### RENABLE SERVICES

for SERVICE in ${SERVICES_ENABLE} ; do
    echo -en "  Enabling service ${SERVICE}..."
    Service_Enable ${SERVICE}
    Service_Start ${SERVICE}
    Check_Return_Code
done

### UNSURE IF REQUIRED

if [[ ! -L "/etc/systemd/system/multi-user.target.wants/gpsd.service" ]] ; then
    echo -en "  Possible fix for GPSd failing to launch on startup, TBC..."
    ACTION=$(sudo ln -s /lib/systemd/system/gpsd.service /etc/systemd/system/multi-user.target.wants/ 2>&1)
    Check_Return_Code
fi

### SETUP COMPLETE

# Return to the project root directory.
if [[ ! "${PWD}" = "${RECEIVER_ROOT_DIRECTORY}" ]] ; then
    echo -en "\e[94m  Returning to ${RECEIVER_PROJECT_TITLE} root directory...\e[97m"
    cd ${RECEIVER_ROOT_DIRECTORY}
    CheckReturnCode
fi

echo -e "\e[93m  ------------------------------------------------------------------------------\n"
echo -e "\e[92m  Installation of GPS based NTP time server is complete.\e[39m"
echo -e ""
if [[ "${RECEIVER_AUTOMATED_INSTALL}" = "false" ]] ; then
    read -p "Press enter to continue..." CONTINUE
fi

exit 0
