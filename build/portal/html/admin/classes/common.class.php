<?php

    /*
    #####################################################################################
    #                                   ADS-B FEEDER                                    #
    #####################################################################################
    #                                                                                   #
    #  A set of scripts created to automate the process of installing the software      #
    #  needed to setup a Mode S decoder as well as feeders which are capable of         #
    #  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
    #                                                                                   #
    #  Project Hosted On GitHub: https://github.com/jprochazka/adsb-feeder              #
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
    */

    class common {

        ////////////////////////////////////////
        // Check if page load is a post back.

        function postBack() {
            if (empty($_SERVER['HTTP_REFERER'])) {
                return FALSE;
            }
            $methodUsed = strtoupper($_SERVER['REQUEST_METHOD']);
            $referer = strtolower(basename($_SERVER['HTTP_REFERER']));
            $thisScript = strtolower(basename($_SERVER['SCRIPT_NAME']));
            if ($methodUsed == 'POST' && $referer == $thisScript) {
                return TRUE;
            }
            return FALSE;
        }

        /////////////////////////////////////
        // Return a boolean from a string.

        function stringToBoolean($value) {
            switch(strtoupper($value)) {
                case 'TRUE': return TRUE;
                case 'FALSE': return FALSE;
                default: return NULL;
            }
        }
    }
?>
