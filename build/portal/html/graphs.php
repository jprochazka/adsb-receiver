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

    // Start session
    session_start();

    // Load the common PHP classes.
    require_once('classes/common.class.php');
    $common = new common();

    // The title and navigation link ID of this page.
    $pageTitle = "Performance Graphs";

    // Get the name of the template to use from the settings.
    $siteName = $common->getSetting("siteName");
    $template = $common->getSetting("template");

    // Enable/disable navigation links.
    $enableBlog = $common->getSetting("enableBlog");
    $enableInfo = $common->getSetting("enableInfo");
    $enableGraphs = $common->getSetting("enableGraphs");
    $enableDump1090 = $common->getSetting("enableDump1090");
    $enableDump978 = $common->getSetting("enableDump978");
    $enablePfclient = $common->getSetting("enablePfclient");

    // Measurement type to use.
    $measurement = $common->getSetting("measurement");

    // Get the network interface being used.
    $networkInterface = $common->getSetting("networkInterface");

    $linkId = $common->removeExtension($_SERVER["SCRIPT_NAME"])."-link";

    // Include the index template.
    require_once('templates/'.$template.'/graphs.tpl.php');

    // Include the master template.
    require_once('templates/'.$template.'/master.tpl.php');
?>
