#!/bin/bash

#####################################################################################
#                                   ADS-B FEEDER                                    #
#####################################################################################
#                                                                                   #
# This script is not meant to be executed directly.                                 #
# Instead execute install.sh to begin the installation process.                     #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015 Joseph A. Prochazka                                            #
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

BUILDDIR=${PWD}

## FUNCTIONS

# Function used to check if a package is install and if not install it.
ATTEMPT=1
function CheckPackage(){
    if (( $ATTEMPT > 5 )); then
        echo -e "\033[33mSCRIPT HALETED! \033[31m[FAILED TO INSTALL PREREQUISITE PACKAGE]\033[37m"
        echo ""
        exit 1
    fi
    printf "\e[33mChecking if the package $1 is installed..."
    if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        if (( $ATTEMPT > 1 )); then
            echo -e "\033[31m [PREVIOUS INSTALLATION FAILED]\033[37m"
            echo -e "\033[33mAttempting to Install the package $1 again in 5 seconds (ATTEMPT $ATTEMPT OF 5)..."
            sleep 5
        else
            echo -e "\033[31m [NOT INSTALLED]\033[37m"
            echo -e "\033[33mInstalling the package $1..."
        fi
        echo -e "\033[37m"
        ATTEMPT=$((ATTEMPT+1))
        sudo apt-get install -y $1;
        echo ""
        CheckPackage $1
    else
        echo -e "\033[32m [OK]\033[37m"
        ATTEMPT=0
    fi
}

clear

echo -e "\033[31m"
echo "--------------------------------------------"
echo " Now ready to install dump1090-MalcolmRobb."
echo "--------------------------------------------"
echo -e "\033[33mDump 1090 is a Mode S decoder specifically designed for RTLSDR devices."
echo ""
echo "https://github.com/MalcolmRobb/dump1090"
echo ""
echo "RTL-SDR will be built and set up as well in order to turn your RTL2832U device into a SDR."
echo ""
echo "http://sdr.osmocom.org/trac/wiki/rtl-sdr"
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Installing packages needed to build and fulfill dependencies..."
echo -e "\033[37m"
CheckPackage git
CheckPackage cmake
CheckPackage libusb-1.0-0-dev
CheckPackage build-essential
CheckPackage pkg-config

## DOWNLOAD THE RTL-SDR SOURCE

echo -e "\033[33m"
echo "Downloading the source code for RTL-SDR..."
echo -e "\033[37m"
git clone git://git.osmocom.org/rtl-sdr.git

## BUILD AND INSTALL RTL-SDR

echo -e "\033[33m"
echo "Building RTL-SDR..."
echo -e "\033[37m"
cd $BUILDDIR/rtl-sdr
mkdir $BUILDDIR/rtl-sdr/build
cd $BUILDDIR/rtl-sdr/build
cmake ../ -DINSTALL_UDEV_RULES=ON
make
sudo make install

## CONFIGURE RTL-SDR

echo -e "\033[33m"
echo "Configuring RTL-SDR..."
echo -e "\033[37m"
sudo ldconfig
sudo cp $BUILDDIR/rtl-sdr/rtl-sdr.rules /etc/udev/rules.d/
sudo tee -a /etc/modprobe.d/no-rtl.conf > /dev/null <<EOF
blacklist dvb_usb_rtl28xxu
blacklist rtl2832
blacklist rtl2830
EOF

echo -e "\033[33mInstallation of RTL-SDR is now complete."
echo "Please look over the output generated to be sure no errors were encountered."
echo "If everything looks good then continue on to install dump1090-MalcolmRobb."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE

## DOWNLOAD THE DUMP1090-MALCOLMROBB SOURCE

cd $BUILDDIR

echo -e "\033[33m"
echo "Downloading the source code for dump1090-MalcolmRobb..."
echo -e "\033[37m"
git clone https://github.com/MalcolmRobb/dump1090.git

## BUILD DUMP1090-MALCOLMROBB

echo -e "\033[33m"
echo "Building dump1090-MalcolmRobb..."
echo -e "\033[37m"
cd $BUILDDIR/dump1090
make

## CREATE A DUMP1090 STARTUP SCRIPT

echo -e "\033[33m"
echo "Creating the dump1090-MalcolmRobb startup script..."
echo -e "\033[37m"
sudo tee -a /etc/init.d/dump1090.sh > /dev/null <<EOF
#!/bin/bash
### BEGIN INIT INFO
#
# Provides:             dump1090
# Required-Start:       \$remote_fs
# Required-Stop:        \$remote_fs
# Default-Start:        2 3 4 5
# Default-Stop:         0 1 6
# Short-Description:    dump1090 initscript

#
### END INIT INFO
## Fill in name of program here.
PROG="dump1090"
PROG_PATH="$BUILDDIR/dump1090"
PROG_ARGS="--interactive --net --no-fix --net-ro-size 500  --net-ro-rate 5"
PIDFILE="/var/run/dump1090.pid"

start() {
      if [ -e \$PIDFILE ]; then
          ## Program is running, exit with error.
          echo "Error: \$PROG is currently running!" 1>&2
          exit 1
      else
          ## Change from /dev/null to something like /var/log/\$PROG if you want to save output.
          cd \$PROG_PATH
          ./\$PROG \$PROG_ARGS 2>&1 >/dev/null &
          echo "\$PROG started"
          touch \$PIDFILE
      fi
}

stop() {
      if [ -e \$PIDFILE ]; then
         ## Program is running, so stop it
         echo "\$PROG is running"
         killall \$PROG
         rm -f \$PIDFILE
         echo "\$PROG stopped"
      else
          ## Program is not running, exit with error.
          echo "Error: \$PROG not started!" 1>&2
          exit 1
      fi
}

## Check to see if we are running as root first.
if [ "\$(id -u)" != "0" ]; then
      echo "This script must be run as root" 1>&2
      exit 1
fi

case "\$1" in
      start)
          start
          exit 0
      ;;
      stop)
          stop
          exit 0
      ;;
      reload|restart|force-reload)
          stop
          start
          exit 0
      ;;
      **)
          echo "Usage: \$0 {start|stop|reload}" 1>&2
          exit 1
      ;;
esac
exit 0
EOF
sudo chmod 755 /etc/init.d/dump1090.sh

## START DUMP1090-MALCOLMROBB

echo -e "\033[33m"
echo "Starting dump1090-MalcolmRobb..."
echo -e "\033[37m"
sudo /etc/init.d/dump1090.sh start

## DISPLAY MESSAGE STATING DUMP1090-MALCOLMROBB SETUP IS COMPLETE

echo -e "\033[33mInstallation and configuration of dump1090-MalcolmRobb is now complete."
echo "Again please look over the output to be sure no errors were encountered."
echo "If no errors were encountered feel free to continue."
echo -e "\033[37m"
read -p "Press enter to continue..." CONTINUE
