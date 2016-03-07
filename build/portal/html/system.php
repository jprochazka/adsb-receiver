<?php

    /////////////////////////////////////////////////////////////////////////////////////
    //                            ADS-B RECEIVER PORTAL                                //
    // =============================================================================== //
    // Copyright and Licensing Information:                                            //
    //                                                                                 //
    // The MIT License (MIT)                                                           //
    //                                                                                 //
    // Copyright (c) 2015-2016 Joseph A. Prochazka                                     //
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
    require_once('classes/template.class.php');

    $common = new common();
    $template = new template();

    $pageData = array();

    // The title of this page.
    $pageData['title'] = "System Information";

    // create aggregate site statistics page links.
    $pageData['flightAwareLink'] = "http://flightaware.com/adsb/stats/user/".$common->getSetting('flightAwareLogin')."#stats-".$common->getSetting('flightAwareSite');
    $pageData['planeFinderLink'] = "https://planefinder.net/sharing/receiver/".$common->getSetting('planeFinderReceiver');
    $pageData['flightRader24Link'] = "https://www.flightradar24.com/premium/feed_stats.php?id=".$common->getSetting('flightRader24Id');
    $pageData['adsbExchangeLink'] = "https://www.adsbexchange.com";

    // Get the current system uptime.
    $json = file_get_contents("http://localhost/api/system.php?action=getUptimeInformation");
    $uptimeData = json_decode($json, TRUE);
    $pageData['uptimeInSeconds'] = $uptimeData['inSeconds'];
    $pageData['uptimeHours'] = $uptimeData['hours'];
    $pageData['uptimeMinutes'] = $uptimeData['minutes'];
    $pageData['uptimeSeconds'] = $uptimeData['seconds'];

    // Get operating system information.
    $json = file_get_contents("http://localhost/api/system.php?action=getOsInformation");
    $osData = json_decode($json, TRUE);
    $pageData['osKernelRelease'] = $osData['kernelRelease'];
    $pageData['osNodeName'] = $osData['nodeName'];
    $pageData['osMachine'] = $osData['machine'];

    // Get CPU information.
    $json = file_get_contents("http://localhost/api/system.php?action=getCpuInformation");
    $cpuData = json_decode($json, TRUE);
    $pageData['cpuModel'] = $cpuData['model'];

    // Get CPU information.
    $json = file_get_contents("http://localhost/api/system.php?action=getHddInformation");
    $hddData = json_decode($json, TRUE);
    $pageData['hddTotal'] = $hddData['total'];
    $pageData['hddUsed'] = $hddData['used'];
    $pageData['hddFree'] = $hddData['free'];
    $pageData['hddPercent'] = $hddData['percent'];

    // Get memory information.
    $json = file_get_contents("http://localhost/api/system.php?action=getMemoryInformation");
    $memData = json_decode($json, TRUE);
    $pageData['memTotal'] = $memData['total'];

    $template->display($pageData);
?>
