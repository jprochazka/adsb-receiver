<?php
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
    $pageData['flightRadar24Link'] = "https://www.flightradar24.com/account/feed-stats/?id=".$common->getSetting('flightRadar24Id');
    $pageData['adsbExchangeLink'] = "http://www.adsbexchange.com";

    // Get software information.
    $pageData['portalVersion'] = $common->getSetting('version');
    $pageData['portalPatch'] = "N/A";
    if ($common->getSetting('patch') != '') {
        $pageData['portalPatch'] = $common->getSetting('patch');
    }

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

    // Get HDD information.
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
