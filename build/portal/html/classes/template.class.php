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

        // PUT THE TEMPLATE TOGETHER

        function display(&$pageData) {
            $common = new Common($this);

            // Load the master template.
            $master = $this->readTemplate('master.tpl');

            // Load the template for the requested page.
            $page = $this->readTemplate($common->removeExtension($_SERVER["SCRIPT_NAME"]).'.tpl');

            $output = $this->mergeAreas($master, $page);
            $output = $this->mergeSettings($output);
            $output = $this->mergeStrings($output);
            $output = $this->mergePageData($output, $pageData);
            $output = $this->processIfs($output);
            $output = $this->removeComments($output);

            // Insert page ID mainly used to mark an active navigation link when using Bootstrap.
            $output = str_replace("{template:pageId}", $common->removeExtension($_SERVER["SCRIPT_NAME"])."-link", $output);

            echo $output;
        }


        // TEMPLATE SYSTEM FUNCTIONS

        // Return the contents of the requested template.
        function readTemplate($template) {
            $common = new Common($this);
            return file_get_contents($_SERVER['DOCUMENT_ROOT']."/templates/".$common->getSetting('template')."/".$template, "r");
        }


        function mergeAreas($master, $template) {
            $pattern = '/\{area:(.*)\}/';
            preg_match_all($pattern, $master, $areas);
            foreach ($areas[0] as $element) {
                $id = $this->extractString($element, ':', '}');
                if (strpos($template, '{area:'.$id.'/}') !== TRUE) {
                    $content = $this->extractString($template, '{area:'.$id.'}', '{/area}');
                    $master = str_replace("{area:".$id."}", $content, $master);
                } else {
                    $master = str_replace("{area:'.$id.'}", "", $master);
                }
            }
            return $master;
        }

        function mergeSettings($output) {
            $common = new Common($this);
            $pattern = '/\{setting:(.*)\}/';
            preg_match_all($pattern, $output, $settings, PREG_PATTERN_ORDER);
            foreach ($settings[0] as $element) {
                $name = $this->extractString($element, ':', '}');
                $value = $common->getSetting($name);
                $output = str_replace("{setting:".$name."}", $value, $output);
            }
            return $output;
        }

        function mergeStrings($output) {
            return $output;
        }

        function mergePageData($output, $pageData) {
            $pattern = '/\{page:(.*)\}/';
            preg_match_all($pattern, $output, $pageVariables, PREG_PATTERN_ORDER);
            foreach ($pageVariables[0] as $element) {
                echo $element."<br />";
                $variable = $this->extractString($element, ':', '}');
                foreach ($pageData as $key => $value) {
                    if ($key == $variable) {
                        $output = str_replace("{page:".$key."}", $value, $output);
                    }
                }
            }
            return $output;
        }

        function processIfs($output) {
            $common = new Common($this);
            $pattern = '/\{if (.*)\}/';
            preg_match_all($pattern, $output, $ifs, PREG_PATTERN_ORDER);
            foreach ($ifs[0] as $element) {
                if (strpos($element, ' eq ') !== FALSE){
                    $operator = "eq";
                } else {
                    $operator = "neq";
                }
                $ifThis = $this->extractString($element, "{if ", " ");
                if (strpos($element, 'setting:') !== FALSE) {
                    $ifThis = $common->getSetting($this->extractString($element, "{if setting:", " "));
                } elseif (strpos($element, 'page:') !== FALSE) {
                    $variable = $this->extractString($element, "{if page:", " ");
                    foreach ($pageData as $key => $value) {
                        if ($key == $variable) {
                            $ifThis = $value;
                        }
                    }
                }

                $that = $this->extractString($element, " ".$operator." ", "}");
                if ($that == "TRUE") {
                    $that = $common->stringToBoolean($that);
                }
                $content = $this->extractString($element, "}", "{/if}");
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

        function removeComments($output) {
            $pattern = '/\{\*(.*?)\*\}/s';
            preg_match_all($pattern, $output, $comments, PREG_PATTERN_ORDER);
            foreach ($comments[0] as $element) {
                $output = str_replace($element, "", $output);
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