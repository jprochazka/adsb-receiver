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
    ====================
     TEMPLATE ELEMENTS:
    ====================
    {area:name}
    {setting:name}
    {page:variable}
    {string:id}
    {* comment *}
    ====================
    */

    class template {

        var $pageData;

        // PUT THE TEMPLATE TOGETHER

        function display($page) {
            // Load the master template.
            $master = $this->readTemplate('master.tpl.php');

            // Load the template for the requested page.
            $page = $this->readTemplate($page.'.tpl.php');

            $output = $this->mergeAreas($master, $page);
            $output = $this->mergeSettings($output);
            $output = $this->mergeStrings($output);
            $output = $this->mergePageData($output);
            $output = $this->removeComments($output);

            // Insert page ID mainly used to mark an active navigation link when using Bootstrap.
            $output = str_replace("{template:pageId}", $common->removeExtension($_SERVER["SCRIPT_NAME"])."-link", $output);

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
                $id = extractString($element, ':', '}');
                if (strpos($template, '{area:'.$id.'/}') !== TRUE) {
                    $content = extractString($template, '{area:'.$id.'}', '{/area}');
                    $master = str_replace("{area:'.$id.'}", $content, $master);
                } else {
                    $master = str_replace("{area:'.$id.'}", "", $master);
                }
            }
            return $master;
        }

        function mergeSettings($output) {
            $common = new Common($this);
            $pattern = '\{setting:(.*)/\}#U';
            preg_match_all($pattern, $output, $settings, PREG_PATTERN_ORDER);
            foreach ($settings[0] as $element) {
                $name = extractString($element, ':', '}');
                $value = $common->getSetting($name);
                $output = str_replace("{setting:'.$name.'}", $value, $output);
            }
            return $output;
        }

        function mergeStrings($output) {
            
        }

        function mergePageData($output) {
            $pattern = '\{page:(.*)/\}#U';
            preg_match_all($pattern, $output, $pageVariables, PREG_PATTERN_ORDER);
            foreach ($pageVariables[0] as $element) {
                $variable = extractString($element, ':', '}');
                foreach ($pageData as $key => $value) {
                    if ($key == $variable) {
                        $output = str_replace("{page:'.$variable.'}", $value, $output);
                    }
                }
            }
        }

        function removeComments($output) {
            $pattern = '\{\*:(.*)/\*\}#U';
            preg_match_all($pattern, $output, $comments, PREG_PATTERN_ORDER);
            foreach ($comments[0] as $element) {
                $output = str_replace($element, "", $output);
            }
            return $output;
        }

        function processIfs($output) {
            $common = new Common($this);
            $pattern = '\{if (.*)/\*{/if}#U';
            preg_match_all($pattern, $output, $ifs, PREG_PATTERN_ORDER);
            foreach ($ifs[0] as $element) {

                if (strpos($element, ' eq ') !== FALSE){
                    $operator == "eq";
                } else {
                    $operator == "neq";
                }

                $ifThis = extractString($element, "{if ", " ");
                if (strpos($element, 'setting:') !== FALSE) {
                    $ifThis = $common->getSetting(extractString($element, "{if setting:", " "));
                } elseif (strpos($element, 'page:') !== FALSE) {
                    $variable = extractString($element, "{if page:", " ");
                    foreach ($pageData as $key => $value) {
                        if ($key == $variable) {
                            $ifThis = $value;
                        }
                    }
                }

                $that = extractString($element, " ".$operator." ", "}")
                $content = extractString($element, "}", "{/if}")
                
                if ($operator == "eq") {
                    if ($ifThis == $that) {
                        $output = str_replace($element, $content, $output);
                    } else {
                        $output = str_replace($element, "", $output);
                    }
                } else {
                    if ($ifThis != $that) {
                        $output = str_replace($element, $content, $output);
                    } else {
                        $output = str_replace($element, "", $output);
                    }
                }
            }
            return $output;
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