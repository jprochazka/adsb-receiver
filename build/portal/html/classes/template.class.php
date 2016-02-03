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

    /*

    {area:name}
    {$variable}
    {* comment *}

    */

    class template {

        // PUT THE TEMPLATE TOGETHER

        function display($page) {
            // Load the master template.
            $master = $this->readTemplate('master.tpl.php');

            // Load the template for the requested page.
            $page = $this->readTemplate($page.'.tpl.php');

            $output = $master;
            $output = mergeAreas($output, $page);
            $output = mergeComments($output);
            $output = mergeVariables($output);
            

            return $output;
        }


        // TEMPLATE SYSTEM FUNCTIONS

        // Return the contents of the requested template.
        function readTemplate($template) {
            $common = new Common($this);
            return file_get_contents($_SERVER['DOCUMENT_ROOT']."/templates/".$common->getSetting('language')."/".$template, "r");
        }


        function mergeAreas($master, $template) {
            $pattern = '\{area:(.*)/\}#U';
            preg_match_all($pattern, $master, $areas, PREG_PATTERN_ORDER);
            foreach ($areas[0] as $element) {
                $id = extractString($element, 'id="', '"');
                if if (strpos($template, '{area:'.$id.'/}') !== TRUE) {
                    $content = extractString($template, '{area:'.$id.'}', '{/area}');
                    $master = str_replace("{area:'.$id.'}", $content, $master);
                } else {
                    $master = str_replace("{area:'.$id.'}", "", $master);
                }
            }
            return $master;
        }

        function mergeComments($template) {

        }

        function mergeVariables($template) {

        }

        function processIfs($template) {

        }


        // Function that returns the string contained between two strings.
        function extractString($string, $start, $end) {
            $string = " ".$string;
            $ini = strpos($string, $start);
            if ($ini == 0) return "";
            $ini += strlen($start);
            $len = strpos($string, $end, $ini) - $ini;
            return substr($string, $ini, $len);
        }
    }
?>