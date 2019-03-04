<?php

    /////////////////////////////////////////////////////////////////////////////////////
    //                            ADS-B RECEIVER PORTAL                                //
    // =============================================================================== //
    // Copyright and Licensing Information:                                            //
    //                                                                                 //
    // The MIT License (MIT)                                                           //
    //                                                                                 //
    // Copyright (c) 2015-2019 Joseph A. Prochazka                                     //
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

    class template {

        // PUT THE TEMPLATE TOGETHER

        function display(&$pageData) {
            $common = new common($this);

            // Check if the portal is installed or needs upgraded.

            $thisVersion = "2.7.1";

            if (!file_exists($_SERVER['DOCUMENT_ROOT']."/classes/settings.class.php")) {
                header ("Location: /install/install.php");
            } elseif ($common->getSetting("version") != $thisVersion){
                header ("Location: /install/upgrade.php");
            }

            // The Base URL of this page (needed for Plane Finder client link)
            $pageData['baseurl'] = $common->getBaseUrl();

            // Load the master template along with required data for the master template..
            $master = $this->readTemplate('master.tpl');

            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."links.class.php");
            $links = new links();
            $pageData['links'] = $links->getAllLinks();

            // Load the template for the requested page.
            $page = $this->readTemplate($common->removeExtension($_SERVER["SCRIPT_NAME"]).'.tpl');

            $output = $this->mergeAreas($master, $page);
            $output = $this->mergeSettings($output);
            $output = $this->mergePageData($output, $pageData);
            $output = $this->processIfs($output, $pageData);
            $output = $this->processForeach($output, $pageData);
            $output = $this->processFors($output, $pageData);
            $output = $this->processWhiles($output, $pageData);
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

            // {area:name}
            // ...
            // {/area}

            $common = new Common($this);
            $pattern = '/\{area:(.*?)\}/';
            preg_match_all($pattern, $master, $areas);
            foreach ($areas[0] as $element) {
                $id = $common->extractString($element, ':', '}');
                if (strpos($template, '{area:'.$id.'/}') !== TRUE) {
                    $content = $common->extractString($template, '{area:'.$id.'}', '{/area}');
                    $master = str_replace("{area:".$id."}", $content, $master);
                } else {
                    $master = str_replace("{area:'.$id.'}", "", $master);
                }
            }
            return $master;
        }

        function mergeSettings($output) {

            // {setting:key}

            $common = new Common($this);
            $pattern = '/\{setting:(.*?)\}/';
            preg_match_all($pattern, $output, $settings, PREG_PATTERN_ORDER);
            foreach ($settings[0] as $element) {
                $name = $common->extractString($element, ':', '}');
                $value = $common->getSetting($name);
                $output = str_replace("{setting:".$name."}", $value, $output);
            }
            return $output;
        }

        function mergePageData($output, $pageData) {

            // {page:key}

            $common = new Common($this);
            $pattern = '/\{page:(.*?)\}/';
            preg_match_all($pattern, $output, $pageVariables, PREG_PATTERN_ORDER);
            foreach ($pageVariables[0] as $element) {
                $variable = $common->extractString($element, ':', '}');
                foreach ($pageData as $key => $value) {
                    if ($key == $variable) {
                        $output = str_replace("{page:".$key."}", $value, $output);
                    }
                }
            }
            return $output;
        }

        function processIfs($output, $pageData) {

            // {if setting:key eq TRUE} ... {else} ... {/if}

            $common = new Common($this);
            $pattern = '/\{if[\s](.*?)\{\/if}/s';
            preg_match_all($pattern, $output, $ifs, PREG_PATTERN_ORDER);
            foreach ($ifs[0] as $element) {
                $pattern = '/\{if[\s](.*?)\}/s';
                preg_match($pattern, $element, $statement);
                if (strpos($statement[0], ' eq ') !== FALSE){
                    $operator = "eq";
                } else {
                    $operator = "neq";
                }
                $ifThis = $common->extractString($statement[0], "{if ", " ");
                if (strpos($statement[0], 'setting:') !== FALSE) {
                    $ifThis = $common->getSetting($common->extractString($statement[0], "{if setting:", " "));
                } elseif (strpos($statement[0], 'page:') !== FALSE) {
                    $variable = $common->extractString($statement[0], "{if page:", " ");
                    foreach ($pageData as $key => $value) {
                        if ($key == $variable) {
                            $ifThis = $value;
                        }
                    }
                }
                $that = $common->extractString($statement[0], " ".$operator." ", "}");
                if ($that == "TRUE") {
                    $that = $common->stringToBoolean($that);
                }
                if ($operator == "eq") {
                    if ($ifThis == $that) {
                        if (preg_match("/\{else\}/s", $element)) {
                            $content = $common->extractString($element, "}", "{else}");
                            $output = str_replace($element, $content, $output);
                        } else {
                            $content = $common->extractString($element, "}", "{/if}");
                            $output = str_replace($element, $content, $output);
                        }
                    } else {
                        if (preg_match("/\{else\}/s", $element)) {
                            $content = $common->extractString($element, "{else}", "{/if}");
                            $output = str_replace($element, $content, $output);
                        } else {
                            $output = str_replace($element, "", $output);
                        }
                    }
                } else {
                    if ($ifThis != $that) {
                        if (preg_match("/\{else\}/s", $element)) {
                            $content = $common->extractString($element, "}", "{else}");
                            $output = str_replace($element, $content, $output);
                        } else {
                            $content = $common->extractString($element, "}", "{/if}");
                            $output = str_replace($element, $content, $output);
                        }
                    } else {
                        if (preg_match("/\{else\}/s", $element)) {
                            $elseContent = $common->extractString($element, "{else}", "{/if}");
                            $output = str_replace($element, $elseContent, $output);
                        } else {
                            $output = str_replace($element, "", $output);
                        }
                    }
                }
            }
            return $output;
        }

        function processForeach($output, $pageData) {

            // {foreach array as item}
            //     ...
            // {/foreach}

            $common = new Common($this);
            $html = NULL;

            $pattern = '/\{foreach(.*?)\{\/foreach\}/s';
            preg_match_all($pattern, $output, $foreach, PREG_PATTERN_ORDER);
            foreach ($foreach[0] as $element) {
                // Loop through $pageData.
                if (strpos($element, 'page:') !== false) {
                    $variable = $common->extractString($element, "{foreach page:", " ");
                    $itemName = $common->extractString($element, "{foreach page:".$variable." as ", "}");
                    $contents = $common->extractString($element, "{foreach page:".$variable." as ".$itemName."}", "{/foreach}");
                    $thisIteration = $contents;
                    foreach ($pageData as $keys => $values) {
                        if ($keys == $variable) {
                            foreach ($values as $item) {
                                foreach ($item as $key => $value) {
                                    $pattern = '/\{'.$itemName.'->(.*?)\}/';
                                    preg_match_all($pattern, $thisIteration, $placeholders, PREG_PATTERN_ORDER);
                                    foreach ($placeholders as $placeholder) {
                                        if (strpos($thisIteration, '{'.$itemName.'->'.$key.'}') !== false) {
                                            $thisIteration = str_replace('{'.$itemName.'->'.$key.'}', $value, $thisIteration);
                                        }
                                    }
                                }
                                $html .= $thisIteration;
                                $thisIteration = $contents;
                            }
                        }
                    }
                    $output = str_replace($element, $html, $output);
                    $html = NULL;
                }
            }
            return $output;
        }

        function processFors($output, $pageData) {

            // {for i eq 1 | i lte 5 | i++}
            //     ...
            // {/for}

            $common = new Common($this);
            $html = NULL;

            $pattern = '/\{for(.*?)\{\/for\}/s';
            preg_match_all($pattern, $output, $fors, PREG_PATTERN_ORDER);
            foreach ($fors[0] as $element) {

                // {for pageNumber eq 1 to page:pageLinks}
                $counterName = $common->extractString($element, "{for ", " ");
                $counter = $common->extractString($element, "{for ", " ");
                $counterValue = $common->extractString($element, "{for ".$counter." eq ", " ");
                $counterLimit = $common->extractString($element, "{for ".$counter." eq ".$counterValue." to ", "}");
                $contents = $common->extractString($element, "{for ".$counter." eq ".$counterValue." to ".$counterLimit."}", "{/for}");
                $thisIteration = $contents;

                // Loop through $pageData.
                if (strpos($element, 'page:') !== false) {
                    $thisCounterValue = $counterValue;
                    $limit = $pageData[str_replace("page:", "", $counterLimit)];
                    for ($counter = $counterValue; $thisCounterValue <= $limit; $thisCounterValue++) {
                        $thisIteration = str_replace('{'.$counterName.'}', $thisCounterValue, $thisIteration);
                        $html .= $thisIteration;
                        $thisIteration = $contents;
                    }
                    $output = str_replace($element, $html, $output);
                }
            }
            return $output;
        }

        function processWhiles($output) {

            // {while i lte 5}
            //     ...
            //     {i++}
            // {/while}

            return $output;
        }

        function removeComments($output) {

            // {* This comment is not to be rendered... *}

            $pattern = '/\{\*(.*?)\*\}/s';
            preg_match_all($pattern, $output, $comments, PREG_PATTERN_ORDER);
            foreach ($comments[0] as $element) {
                $output = str_replace($element, "", $output);
            }
            return $output;
        }
    }
?>
