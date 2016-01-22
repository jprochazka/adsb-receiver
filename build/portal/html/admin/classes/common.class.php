<?php

    /////////////////////////////////////////////////////////////////////////////////////
    //                             ADS-B FEEDER PORTAL                                 //
    // =============================================================================== //
    // Copyright and Licensing Information:                                            //
    //                                                                                 //
    // The MIT License (MIT)                                                           //
    //                                                                                 //
    // Copyright (c) 2015 Joseph A. Prochazka                                          //
    //                                                                                 //
    // Permission is hereby granted, free of charge, to any person obtaining a copy    //
    // of this software and associated documentation files (the "Software"), to deal   //
    // in the Software without restriction, including without limitation the rights    //
    // to use, copy, modify, merge, publish, distribute, sublicense, and/or sell       //
    // copies of the Software, and to permit persons to whom the Software is           //
    // furnished to do so, subject to the following conditions:                        //
    //                                                                                 //
    // The above copyright notice and this permission notice shall be included in all  //
    // copies or substantial portions of the Software.                                 //
    //                                                                                 //
    // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR      //
    // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,        //
    // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE     //
    // AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER          //
    // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,   //
    // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE   //
    // SOFTWARE.                                                                       //
    /////////////////////////////////////////////////////////////////////////////////////

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

        //////////////////////////////////////////////////////////
        // Returns the supplied file name without an extension.

        function removeExtension($fileName) {
            return pathinfo($fileName, PATHINFO_FILENAME);
        }

        ///////////////////////////////////////////////////////
        // Returns the value for the specified setting name.

        function getSetting($name) {
            $settings = simplexml_load_file("../data/settings.xml") or die("Error: Cannot create settings object");
            foreach ($settings as $setting) {
                if ($setting->name == $name) {
                    return $setting->value;
                }
            }
            return "default";
        }

        ///////////////////////////////////////////////////////
        // Updates the value for the specified setting name.

        function updateSetting($name, $value) {
            $settings = simplexml_load_file("../data/settings.xml") or die("Error: Cannot create settings object");
            foreach ($settings->xpath("setting[name='".$name."']") as $setting) {
                $setting->value = $value;
            }
            file_put_contents("../data/settings.xml", $settings->asXML());
        }
    }
?>
