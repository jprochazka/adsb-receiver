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

#######################################################################
# Detect if a package is installed and if not attempt to install it.

function CheckPackage {
    ATTEMPT=1
    MAXATTEMPTS=5
    WAITTIME=5

    while (( $ATTEMPT -le `(($MAXATTEMPTS + 1))` )); do

        # If the maximum attempts has been reached...
        if [ $ATTEMPT -gt $MAXATTEMPTS ]; then
            echo -e "\033[31m"
            echo "#########################################"
            echo "# INSTALLATION HALTED!                  #"
            echo "# UNABLE TO INSTALL A REQUIRED PACKAGE. #"
            echo "#########################################"
            echo -e "\033[33m"
            echo "The package \"$1\" could not be installed in $MAXATTEMPTS attempts."
            echo -e "\033[37m"
            exit 1
        fi

        # Check if the package is already installed.
        printf "\033[33mChecking if the package $1 is installed..."
        if [ $(dpkg-query -W -f='${STATUS}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then

            # If this is not the first attempt at installing this package...
            if [ $ATTEMPT -gt 1 ]; then
                echo -e "\033[31m [PREVIOUS INSTALLATION FAILED]"
                echo -e "\033[33mAttempting to Install the package $1 again in $WAITTIME seconds (ATTEMPT $ATTEMPT OF $MAXATTEMPTS)..."
                sleep $WAITTIME
            else
                echo -e "\033[31m [NOT INSTALLED]"
                echo -e "\033[33mInstalling the package $1..."
            fi

            # Attempt to install the required package.
            echo ""
            ATTEMPT=$((ATTEMPT+1))
            sudo apt-get install -y $1
            echo ""
        else
            # The package appears to be installed.
            echo -e "\033[32m [OK]\033[37m"
            break
        fi
    done
}

