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

## VARIABLES

PROJECTROOTDIRECTORY="$PWD"
BUILDDIRECTORY="$PROJECTROOTDIRECTORY/build"
PORTALBUILDDIRECTORY="$BUILDDIRECTORY/portal"
PYTHONPATH=`which python`

## SETUP FLIGHT LOGGING

echo ""
echo -e "\e[95m  Setting up flight logging...\e[97m"
echo ""

case $DATABASEENGINE in
    "MySQL")
        echo -e "\e[94m  Creating the flight logging configuration file for MySQL...\e[97m"
        tee $PORTALBUILDDIRECTORY/logging/config.json > /dev/null <<EOF
{
    "database":{"type":"mysql",
                "host":"$DATABASEHOST",
                "user":"$DATABASEUSER",
                "passwd":"$DATABASEPASSWORD1",
                "db":"$DATABASENAME"}
}
EOF
            ;;
    "SQLite")
        echo -e "\e[94m  Creating the flight logging configuration file for SQLite...\e[97m"
        tee $PORTALBUILDDIRECTORY/logging/config.json > /dev/null <<EOF
{
    "database":{"type":"sqlite",
                "host":"",
                "user":"",
                "passwd":"",
                "db":"$LIGHTTPDDOCUMENTROOT/data/portal.sqlite"}
}
EOF
        ;;
    *)
        echo ""
        echo -e "\e[91m  \e[5mINSTALLATION HALTED!\e[25m"
        echo -e "  SETUP HAS BEEN TERMINATED!"
        echo ""
        echo -e "\e[93mInvalid \"DATABASEENGINE\" supplied.\e[39m"
        echo ""
        echo -e "\e[93m----------------------------------------------------------------------------------------------------"
        echo -e "\e[92m  ADS-B Receiver Project Portal (Advanced) setup.\e[39m"
        echo ""
        read -p "Press enter to continue..." CONTINUE
        exit 1
        ;;
esac

# Create and set permissions on the flight logging and maintenance maintenance scripts.
echo -e "\e[94m  Creating the flight logging maintenance script...\e[97m"
tee $PORTALBUILDDIRECTORY/logging/flights-maint.sh > /dev/null <<EOF
#!/bin/sh
while true
  do
    sleep 30
        $PYTHONPATH $PORTALBUILDDIRECTORY/logging/flights.py
  done
EOF

echo -e "\e[94m  Creating the maintenance maintenance script...\e[97m"
tee $PORTALBUILDDIRECTORY/logging/maintenance-maint.sh > /dev/null <<EOF
#!/bin/sh
while true
  do
    sleep 30
        $PYTHONPATH $PORTALBUILDDIRECTORY/portal/logging/maintenance.py
  done
EOF

echo -e "\e[94m  Making the flight logging maintenance script executable...\e[97m"
chmod +x $PORTALBUILDDIRECTORY/logging/flights-maint.sh
echo -e "\e[94m  Making the maintenance maintenance script executable...\e[97m"
chmod +x $PORTALBUILDDIRECTORY/logging/maintenance-maint.sh

# Add flight logging maintenance script to rc.local.
if ! grep -Fxq "$PORTALBUILDDIRECTORY/logging/flights-maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the flight logging maintenance script startup line to /etc/rc.local...\e[97m"
    LINENUMBER=($(sed -n '/exit 0/=' /etc/rc.local))
    ((LINENUMBER>0)) && sudo sed -i "${LINENUMBER[$((${#LINENUMBER[@]}-1))]}i $PORTALBUILDDIRECTORY/logging/flights-maint.sh &\n" /etc/rc.local
fi

# Add maintenance maintenance script to rc.local.
if ! grep -Fxq "$PORTALBUILDDIRECTORY/logging/maintenance-maint.sh &" /etc/rc.local; then
    echo -e "\e[94m  Adding the maintenance maintenance script startup line to /etc/rc.local...\e[97m"
    LINENUMBER=($(sed -n '/exit 0/=' /etc/rc.local))
    ((LINENUMBER>0)) && sudo sed -i "${LINENUMBER[$((${#LINENUMBER[@]}-1))]}i $PORTALBUILDDIRECTORY/logging/maintenance-maint.sh &\n" /etc/rc.local
fi

# Start flight logging.
echo -e "\e[94m  Executing the flight logging maintenance script...\e[97m"
nohup $PORTALBUILDDIRECTORY/logging/flights-maint.sh > /dev/null 2>&1 &

# Start maintenance..
echo -e "\e[94m  Executing the maintenance maintenance script...\e[97m"
nohup $PORTALBUILDDIRECTORY/portal/logging/flights-maint.sh > /dev/null 2>&1 &
