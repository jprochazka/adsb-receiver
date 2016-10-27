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

    session_start();

    // Load the require PHP classes.
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."account.class.php");

    $settings = new settings();
    $common = new common();
    $account = new account();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php");
    }

    // Set updated variable to FALSE.
    $updated = FALSE;

    if ($common->postBack()) {
        // Flight notifications
        $notificationArray = explode(',', $_POST['notifications']);

        if ($settings::db_driver == "xml") {
            // XML
            $notifications = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."notifications.xml");
            unset($notifications->flight);
            foreach ($notificationArray as $notification) {
                $flight = $notifications->addChild('flight', '');
                $flight->addChild('name', $notification);
                $flight->addChild('lastMessageCount', -1);
                $dom = dom_import_simplexml($notifications)->ownerDocument;
                $dom->preserveWhiteSpace = FALSE;
                $dom->formatOutput = TRUE;
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."notifications.xml", $dom->saveXML());
            }
        } else {
            // PDO
            $dbh = $common->pdoOpen();
            $sql = "SELECT * FROM ".$settings::db_prefix."notifications";
            $sth = $dbh->prepare($sql);
            $sth->execute();
            $savedFlights = $sth->fetchAll();
            $sth = NULL;
            $dbh = NULL;
            foreach ($savedFlights as $flight) {
                // Remove flight if not in list.
                if (!in_array($flight, $notificationArray)) {
                    $dbh = $common->pdoOpen();
                    $sql = "DELETE FROM ".$settings::db_prefix."notifications WHERE flight = :flight";
                    $sth = $dbh->prepare($sql);
                    $sth->bindParam(':flight', $flight['flight'], PDO::PARAM_STR, 10);
                    $sth->execute();
                    $sth = NULL;
                    $dbh = NULL;
                }
            }
            foreach ($notificationArray as $flight) {
                // Add flight if not saved already.
                if (!in_array($flight, $savedFlights)) {
                    $dbh = $common->pdoOpen();
                    $sql = "INSERT INTO ".$settings::db_prefix."notifications (flight, lastMessageCount) VALUES (:flight, :lastMessageCount)";
                    $sth = $dbh->prepare($sql);
                    $sth->bindParam(':flight', $flight, PDO::PARAM_STR, 10);
                    $sth->bindParam(':lastMessageCount', $a = 0, PDO::PARAM_INT);
                    $sth->execute();
                    $sth = NULL;
                    $dbh = NULL;
                }
            }
        }

        // Set TRUE or FALSE for checkbox items.
        $enableFlights = FALSE;
        if (isset($_POST['enableFlights']) && $_POST['enableFlights'] == "TRUE")
            $enableFlights = TRUE;

        $enableBlog = FALSE;
        if (isset($_POST['enableBlog']) && $_POST['enableBlog'] == "TRUE")
            $enableBlog = TRUE;

        $enableInfo = FALSE;
        if (isset($_POST['enableInfo']) && $_POST['enableInfo'] == "TRUE")
            $enableInfo = TRUE;

        $enableGraphs = FALSE;
        if (isset($_POST['enableGraphs']) && $_POST['enableGraphs'] == "TRUE")
            $enableGraphs = TRUE;

        $enableLinks = FALSE;
        if (isset($_POST['enableLinks']) && $_POST['enableLinks'] == "TRUE")
            $enableLinks = TRUE;

        $enableDump1090 = FALSE;
        if (isset($_POST['enableDump1090']) && $_POST['enableDump1090'] == "TRUE")
            $enableDump1090 = TRUE;

        $enableDump978 = FALSE;
        if (isset($_POST['enableDump978']) && $_POST['enableDump978'] == "TRUE")
            $enableDump978 = TRUE;

        $enablePfclient = FALSE;
        if (isset($_POST['enablePfclient']) && $_POST['enablePfclient'] == "TRUE")
            $enablePfclient = TRUE;

        $enableFlightAwareLink = FALSE;
        if (isset($_POST['enableFlightAwareLink']) && $_POST['enableFlightAwareLink'] == "TRUE")
            $enableFlightAwareLink = TRUE;

        $enablePlaneFinderLink = FALSE;
        if (isset($_POST['enablePlaneFinderLink']) && $_POST['enablePlaneFinderLink'] == "TRUE")
            $enablePlaneFinderLink = TRUE;

        $enableFlightRadar24Link = FALSE;
        if (isset($_POST['enableFlightRadar24Link']) && $_POST['enableFlightRadar24Link'] == "TRUE")
            $enableFlightRadar24Link = TRUE;

        $enableAdsbExchangeLink = FALSE;
        if (isset($_POST['enableAdsbExchangeLink']) && $_POST['enableAdsbExchangeLink'] == "TRUE")
            $enableAdsbExchangeLink = TRUE;

        $enableWebNotifications = FALSE;
        if (isset($_POST['enableWebNotifications']) && $_POST['enableWebNotifications'] == "TRUE")
            $enableWebNotifications = TRUE;

        $enableEmailNotifications = FALSE;
        if (isset($_POST['enableEmailNotifications']) && $_POST['enableEmailNotifications'] == "TRUE")
            $enableEmailNotifications = TRUE;

        $enableTwitterNotifications = FALSE;
        if (isset($_POST['enableTwitterNotifications']) && $_POST['enableTwitterNotifications'] == "TRUE")
            $enableTwitterNotifications = TRUE;

        // Update settings using those supplied by the form.
        $common->updateSetting("siteName", $_POST['siteName']);
        $common->updateSetting("template", $_POST['template']);
        $common->updateSetting("defaultPage", $_POST['defaultPage']);
        $common->updateSetting("dateFormat", $_POST['dateFormat']);
        $common->updateSetting("enableFlights", $enableFlights);
        $common->updateSetting("enableBlog", $enableBlog);
        $common->updateSetting("enableInfo", $enableInfo);
        $common->updateSetting("enableGraphs", $enableGraphs);
        $common->updateSetting("enableLinks", $enableLinks);
        $common->updateSetting("enableDump1090", $enableDump1090);
        $common->updateSetting("enableDump978", $enableDump978);
        $common->updateSetting("enablePfclient", $enablePfclient);
        $common->updateSetting("enableFlightAwareLink", $enableFlightAwareLink);
        $common->updateSetting("flightAwareLogin", $_POST['flightAwareLogin']);
        $common->updateSetting("flightAwareSite", $_POST['flightAwareSite']);
        $common->updateSetting("enablePlaneFinderLink", $enablePlaneFinderLink);
        $common->updateSetting("planeFinderReceiver", $_POST['planeFinderReceiver']);
        $common->updateSetting("enableFlightRadar24Link", $enableFlightRadar24Link);
        $common->updateSetting("flightRadar24Id", $_POST['flightRadar24Id']);
        $common->updateSetting("enableAdsbExchangeLink", $enableAdsbExchangeLink);
        $common->updateSetting("measurementRange", $_POST['measurementRange']);
        $common->updateSetting("measurementTemperature", $_POST['measurementTemperature']);
        $common->updateSetting("measurementBandwidth", $_POST['measurementBandwidth']);
        $common->updateSetting("networkInterface", $_POST['networkInterface']);
        $common->updateSetting("timeZone", $_POST['timeZone']);
        $common->updateSetting("enableWebNotifications", $enableWebNotifications);
        $common->updateSetting("enableEmailNotifications", $enableEmailNotifications);
        $common->updateSetting("enableTwitterNotifications", $enableTwitterNotifications);
        $common->updateSetting("emailNotificationAddresses", $_POST['emailNotificationAddresses']);
        $common->updateSetting("twitterUserName", $_POST['twitterUserName']);
        $common->updateSetting("twitterConsumerKey", $_POST['twitterConsumerKey']);
        $common->updateSetting("twitterConsumerSecret", $_POST['twitterConsumerSecret']);
        $common->updateSetting("twitterAccessToken", $_POST['twitterAccessToken']);
        $common->updateSetting("twitterAccessTokenSecret", $_POST['twitterAccessTokenSecret']);
        $common->updateSetting("googleMapsApiKey", $_POST['googleMapsApiKey']);

        // Purge older flight positions.
        if (isset($_POST['purgepositions'])) {
            $dbh = $common->pdoOpen();
            $sql = "DELETE FROM ".$settings::db_prefix."positions WHERE time < :purgeDate";
            $sth = $dbh->prepare($sql);
            $sth->bindParam(':purgeDate', $_POST['purgepositionspicker'], PDO::PARAM_STR, 100);
            $sth->execute();
            $sth = NULL;
            $dbh = NULL;
        }

        // Set updated to TRUE since settings were updated.
        $updated = TRUE;
    }

    // Get notification settings.
    $notifications = NULL;
    $savedFlights = array();
    if ($settings::db_driver == "xml") {
        // XML
        $savedFlights = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."notifications.xml");
        foreach ($savedFlights as $savedFlight) {
            $notifications = ltrim($notifications.",".$savedFlight->name, ',');
        }
    } else {
        //PDO
        $dbh = $common->pdoOpen();
        $sql = "SELECT * FROM ".$settings::db_prefix."notifications";
        $sth = $dbh->prepare($sql);
        $sth->execute();
        $savedFlights = $sth->fetchAll();
        $sth = NULL;
        $dbh = NULL;
        foreach ($savedFlights as $savedFlight) {
            $notifications = ltrim($notifications.",".$savedFlight['flight'], ',');
        }
    }
    $enableWebNotifications = $common->getSetting("enableWebNotifications");
    $enableEmailNotifications = $common->getSetting("enableEmailNotifications");
    $enableTwitterNotifications = $common->getSetting("enableTwitterNotifications");
    $emailNotificationAddresses = $common->getSetting("emailNotificationAddresses");
    $twitterUserName = $common->getSetting("twitterUserName");
    $twitterConsumerKey = $common->getSetting("twitterConsumerKey");
    $twitterConsumerSecret = $common->getSetting("twitterConsumerSecret ");
    $twitterAccessToken = $common->getSetting("twitterAccessToken");
    $twitterAccessTokenSecret = $common->getSetting("twitterAccessTokenSecret");

    // Get general settings from settings.xml.
    $siteName = $common->getSetting("siteName");
    $currentTemplate = $common->getSetting("template");
    $defaultPage = $common->getSetting("defaultPage");
    $dateFormat = $common->getSetting("dateFormat");
    $timeZone = $common->getSetting("timeZone");
    $googleMapsApiKey = $common->getSetting("googleMapsApiKey");

    // Get navigation settings from settings.xml.
    $enableFlights = $common->getSetting("enableFlights");
    $enableBlog = $common->getSetting("enableBlog");
    $enableInfo = $common->getSetting("enableInfo");
    $enableGraphs = $common->getSetting("enableGraphs");
    $enableLinks = $common->getSetting("enableLinks");
    $enableDump1090 = $common->getSetting("enableDump1090");
    $enableDump978 = $common->getSetting("enableDump978");
    $enablePfclient = $common->getSetting("enablePfclient");

    // Get aggregate site settings from settings.xml.
    $enableFlightAwareLink = $common->getSetting("enableFlightAwareLink");
    $flightAwareLogin = $common->getSetting("flightAwareLogin");
    $flightAwareSite = $common->getSetting("flightAwareSite");
    $enablePlaneFinderLink = $common->getSetting("enablePlaneFinderLink");
    $planeFinderReceiver = $common->getSetting("planeFinderReceiver");
    $enableFlightRadar24Link = $common->getSetting("enableFlightRadar24Link");
    $flightRadar24Id = $common->getSetting("flightRadar24Id");
    $enableAdsbExchangeLink = $common->getSetting("enableAdsbExchangeLink");

    // Get units of measurement setting from settings.xml.
    $measurementRange = $common->getSetting("measurementRange");
    $measurementTemperature = $common->getSetting("measurementTemperature");
    $measurementBandwidth = $common->getSetting("measurementBandwidth");

    // Get the network interface from settings.xml.
    $networkInterface = $common->getSetting("networkInterface");

    // Create an array of all directories in the template folder.
    $templates = array();
    $path = "../templates/";
    $directoryHandle = @opendir($path) or die('Unable to open directory "'.$path.'".');
    while($templateDirectory = readdir($directoryHandle)) {
        if (is_dir($path."/".$templateDirectory)) {
            if ($templateDirectory != "." && $templateDirectory != "..") {
                array_push($templates, $templateDirectory);
            }
        }
    }
    closedir($directoryHandle);

    // Function used to format offsets of timezones.
    function formatOffset($offset) {
        return sprintf('%+03d:%02u', floor($offset / 3600), floor(abs($offset) % 3600 / 60));
    }
    $utc = new DateTimeZone('UTC');
    $dt = new DateTime('now', $utc);

    ////////////////
    // BEGIN HTML

    require_once('includes/header.inc.php');

    // Display the updated message if settings were updated.
    if ($updated) {
?>
        <div id="settings-saved" class="alert alert-success fade in" role="alert">
            <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
            Settings have been updated.
        </div>
<?php
    }
?>
        <form method="post" action="index.php">
            <ul class="nav nav-tabs" role="tablist">
                <li role="presentation" class="active"><a href="#general" aria-controls="general" role="tab" data-toggle="tab">General</a></li>
                <li role="presentation"><a href="#notifications" aria-controls="notifications" role="tab" data-toggle="tab">Notifications</a></li>
                <li role="presentation"><a href="#navigation" aria-controls="navigation" role="tab" data-toggle="tab">Navigation</a></li>
                <li role="presentation"><a href="#measurments" aria-controls="measurments" role="tab" data-toggle="tab">Measurements</a></li>
                <li role="presentation"><a href="#system" aria-controls="system" role="tab" data-toggle="tab">System</a></li>
                <li role="presentation"><a href="#maintenance" aria-controls="maintenance" role="tab" data-toggle="tab">Maintenance</a></li>
            </ul>
            <div class="padding"></div>
            <div class="tab-content">
                <div role="tabpanel" class="tab-pane fade in active" id="general">
                    <div class="panel panel-default">
                        <div class="panel-heading">Site Layout</div>
                        <div class="panel-body">
                            <div class="form-group">
                                <label for="siteName">Site Name</label>
                                <input type="text" class="form-control" id="siteName" name="siteName" value="<?php echo $siteName; ?>">
                            </div>
                            <div class="form-group">
                                <label for="template">Template</label>
                                <select class="form-control" id="template" name="template">
        <?php
            foreach ($templates as $template) {
                                echo '                          <option value="'.$template.'"'.($template == $currentTemplate ? ' selected' : '').'>'.$template.'</option>'."\n";
            }
        ?>
                                </select>
                            </div>
                            <div class="form-group">
                                <label for="defaultPage">Default Page</label>
                                <select class="form-control" id="defaultPage" name="defaultPage">
                                    <option value="blog.php"<?php ($defaultPage == "blog.php" ? print ' selected' : ''); ?>>Blog</option>
                                    <option value="system.php"<?php ($defaultPage == "system.php" ? print ' selected' : ''); ?>>System Information</option>
                                    <option value="graphs.php"<?php ($defaultPage == "graphs.php" ? print ' selected' : ''); ?>>Performance Graphs</option>
                                    <option value="dump1090.php"<?php ($defaultPage == "dump1090.php" ? print ' selected' : ''); ?>>Live Dump1090 Map</option>
                                    <option value="dump978.php"<?php ($defaultPage == "dump978.php" ? print ' selected' : ''); ?>>Live Dump978 Map</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label for="defaultPage">Date Format - 12 Hour Format</label>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="F jS, Y g:i A"<?php ($dateFormat == "F jS, Y g:i A" ? print ' checked' : ''); ?>>October 16, 2015 5:00 PM</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="Y-m-d g:i A"<?php ($dateFormat == "Y-m-d g:i A" ? print ' checked' : ''); ?>>2015-10-16 5:00 PM</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="m/d/Y g:i A"<?php ($dateFormat == "m/d/Y g:i A" ? print ' checked' : ''); ?>>16/10/2015 5:00 PM</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="d/m/Y g:i A"<?php ($dateFormat == "d/m/Y g:i A" ? print ' checked' : ''); ?>>10/16/2015 5:00 PM</label>
                                </div>
                                <label for="defaultPage">Date Format - 24 Hour Format</label>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="F jS, Y G:i"<?php ($dateFormat == "F jS, Y G:i" ? print ' checked' : ''); ?>>October 16, 2015 17:00</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="Y-m-d G:i"<?php ($dateFormat == "Y-m-d G:i" ? print ' checked' : ''); ?>>2015-10-16 17:00</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="m/d/Y G:i"<?php ($dateFormat == "m/d/Y G:i" ? print ' checked' : ''); ?>>16/10/2015 17:00</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="d/m/Y G:i"<?php ($dateFormat == "d/m/Y G:i" ? print ' checked' : ''); ?>>10/16/2015 17:00</label>
                                </div>
                                <input type="text" class="form-control" id="dateFormat" name="dateFormat" value="<?php echo $dateFormat; ?>">
                            </div>
                            <div class="form-group">
                                <label for="timeZone">Time Zone</label>
                                <select class="form-control" id="timeZone" name="timeZone">
<?php
    foreach (DateTimeZone::listIdentifiers() as $tz) {
        $currentTimeZone = new DateTimeZone($tz);
        $offSet = $currentTimeZone->getOffset($dt);
        $transition = $currentTimeZone->getTransitions($dt->getTimestamp(), $dt->getTimeStamp());
        $abbr = $transition[0]['abbr'];
?>
                                    <option name="timeZone" value="<?php echo $tz; ?>"<?php ($tz == $timeZone ? print " selected" : ""); ?>><?php echo $tz; ?> [<?php echo $abbr; ?> <?php echo formatOffset($offSet);?>]</option>
<?php
    }
?>
                                </select>
                            </div>
                            <div class="form-group">
                                <label for="googleMapsApiKey">Google Maps API Key</label>
                                <input type="text" class="form-control" id="googleMapsApiKey" name="googleMapsApiKey" value="<?php echo $googleMapsApiKey; ?>">
                            </div>
                        </div>
                    </div>
                </div>
                <div role="tabpanel" class="tab-pane fade" id="notifications">
                    <div class="panel panel-default">
                        <div class="panel-heading">Flight Notifications</div>
                        <div class="panel-body">
                            <div class="form-group">
                                <label for="notifications"">Flight names. (coma delimited)</label>
                                <input type="text" class="form-control" id="notifications" name="notifications" value="<?php echo $notifications; ?>">
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableWebNotifications" value="TRUE"<?php ($enableWebNotifications == 1 ? print ' checked' : ''); ?>> Enable web based flight notifications.
                                </label>
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableEmailNotifications" value="TRUE"<?php ($enableEmailNotifications == 1 ? print ' checked' : ''); ?>> Enable email flight notifications.
                                </label>
                            </div>
                            <div class="form-group">
                                <label for="emailNotificationAddresses"">Email addresses to be notified. (coma delimited)</label>
                                <input type="text" class="form-control" id="emailNotificationAddresses" name="emailNotificationAddresses" value="<?php echo $emailNotificationAddresses; ?>">
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableTwitterNotifications" value="TRUE"<?php ($enableTwitterNotifications == 1 ? print ' checked' : ''); ?>> Enable Twitter flight notifications.
                                </label>
                            </div>
                            <div class="form-group">
                                <label for="twitterUserName">Twitter User Name</label>
                                <input type="text" class="form-control" id="twitterUserName" name="twitterUserName" value="<?php echo $twitterUserName; ?>">
                            </div>
                            <div class="form-group">
                                <label for="twitterConsumerKey">Twitter Consumer Key</label>
                                <input type="text" class="form-control" id="twitterConsumerKey" name="twitterConsumerKey" value="<?php echo $twitterConsumerKey; ?>">
                            </div>
                            <div class="form-group">
                                <label for="twitterConsumerSecret">Twitter</label>
                                <input type="text" class="form-control" id="twitterConsumerSecret" name="twitterConsumerSecret" value="<?php echo $twitterConsumerSecret; ?>">
                            </div>
                            <div class="form-group">
                                <label for="twitterAccessToken">Twitter</label>
                                <input type="text" class="form-control" id="twitterAccessToken" name="twitterAccessToken" value="<?php echo $twitterAccessToken; ?>">
                            </div>
                            <div class="form-group">
                                <label for="twitterAccessTokenSecret">Twitter</label>
                                <input type="text" class="form-control" id="twitterAccessTokenSecret" name="twitterAccessTokenSecret" value="<?php echo $twitterAccessTokenSecret; ?>">
                            </div>
                        </div>
                    </div>
                </div>
                <div role="tabpanel" class="tab-pane fade" id="navigation">
                  <div class="panel panel-default">
                      <div class="panel-heading">API Key</div>
                      <div class="panel-body">
                        <div class="form-group">
                                <label for="BingMapsAPI">Bing Maps API Key</label>
                                <input type="text" class="form-control" id="bingMapAPIKey" name="bingMapAPIKey"
                                        value="<?php  if(!empty($_POST['bingMapAPIKey'])){
                                        $apikey = $_POST['bingMapAPIKey'];
                                        $path_to_file = '/usr/share/dump1090-mutability/html/config.js';
                                        $file_contents = file_get_contents($path_to_file);
                                        $file_contents = preg_replace('/BingMapsAPIKey = ([a-zA-Z0-9"]+)/', "BingMapsAPIKey = '" . $_POST['bingMapAPIKey'] . "'" , $file_contents);
                                        file_put_contents($path_to_file,$file_contents);
                                        }
                                        else {
                                          echo file_get_contents('/usr/share/dump1090-mutability/html/config.js');
                                        }
                                        ?>">
                                </div>
                                <div class="form-group">
                                        <label for="mapzenAPIKey">Mapzen Maps API Key</label>
                                        <input type="text" class="form-control" id="mapzenAPIKey" name="mapzenAPIKey"
                                                value="<?php  if(!empty($_POST['mapzenAPIKey'])){
                                                $apikey = $_POST['mapzenAPIKey'];
                                                $path_to_file = '/usr/share/dump1090-mutability/html/config.js';
                                                $file_contents = file_get_contents($path_to_file);
                                                $file_contents = preg_replace('/MapzenAPIKey = ([a-zA-Z0-9"]+)/', "MapzenAPIKey = '" . $_POST['mapzenAPIKey'] . "'" , $file_contents);
                                                file_put_contents($path_to_file,$file_contents);
                                                }
                                                else {
                                                  echo file_get_contents('/usr/share/dump1090-mutability/html/config.js');
                                                }
                                                ?>">
                                        </div>
                        </div>
                      </div>
                    <div class="panel panel-default">
                        <div class="panel-heading">Enable/Disable Navigation Links</div>
                        <div class="panel-body">
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableFlights" value="TRUE"<?php ($enableFlights == 1 ? print ' checked' : ''); ?><?php ($settings::db_driver == "xml" ? print ' disabled' : ''); ?>> Enable flights link.
                                </label>
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableBlog" value="TRUE"<?php ($enableBlog == 1? print ' checked' : ''); ?>> Enable blog link.
                                </label>
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableInfo" value="TRUE"<?php ($enableInfo == 1? print ' checked' : ''); ?>> Enable system information link.
                                </label>
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableGraphs" value="TRUE"<?php ($enableGraphs == 1 ? print ' checked' : ''); ?>> Enable performance graphs link.
                                </label>
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableLinks" value="TRUE"<?php ($enableLinks == 1 ? print ' checked' : ''); ?>> Enable custom links.
                                </label>
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableDump1090" value="TRUE"<?php ($enableDump1090 == 1 ? print ' checked' : ''); ?>> Enable live dump1090 map link.
                                </label>
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableDump978" value="TRUE"<?php ($enableDump978 == 1 ? print ' checked' : ''); ?>> Enable live dump978 map link.
                                </label>
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enablePfclient" value="TRUE"<?php ($enablePfclient == 1 ? print ' checked' : ''); ?>> Enable Planefinder ADS-B Client link.
                                </label>
                            </div>
                        </div>
                    </div>
                    <div class="panel panel-default">
                        <div class="panel-heading">Aggregate Site Settings</div>
                        <div class="panel-body">
                            <div class="form-group">
                                <label for="flightAwareLogin">FlightAware Login</label>
                                <input type="text" class="form-control" id="flightAwareLogin" name="flightAwareLogin" value="<?php echo $flightAwareLogin; ?>">
                                <label for="flightAwareSite">FlightAware ADS-B Site</label>
                                <input type="text" class="form-control" id="flightAwareSite" name="flightAwareSite" value="<?php echo $flightAwareSite; ?>">
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="enableFlightAwareLink" value="TRUE"<?php ($enableFlightAwareLink == 1 ? print ' checked' : ''); ?>> Enable FlightAware Statistics Link.
                                    </label>
                                </div>
                            </div>
                            <hr />
                            <div class="form-group">
                                <label for="planeFinderReceiver">PlaneFinder Receiver Number</label>
                                <input type="text" class="form-control" id="planeFinderReceiver" name="planeFinderReceiver" value="<?php echo $planeFinderReceiver; ?>">
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="enablePlaneFinderLink" value="TRUE"<?php ($enablePlaneFinderLink == 1 ? print ' checked' : ''); ?>> Enable PlaneFinder Statistics Link.
                                    </label>
                                </div>
                            </div>
                            <hr />
                            <div class="form-group">
                                <label for="flightRadar24FeedStatsId">FlightRadar24 Feed Stats ID</label>
                                <input type="text" class="form-control" id="flightRadar24Id" name="flightRadar24Id" value="<?php echo $flightRadar24Id; ?>">
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="enableFlightRadar24Link" value="TRUE"<?php ($enableFlightRadar24Link == 1 ? print ' checked' : ''); ?>> Enable FlightRadar24 Statistics Link.
                                    </label>
                                </div>
                            </div>
                            <hr />
                            <div class="form-group">
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="enableAdsbExchangeLink" value="TRUE"<?php ($enableAdsbExchangeLink == 1 ? print ' checked' : ''); ?>> Enable ADSB-Exchange Link.
                                    </label>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                <div role="tabpanel" class="tab-pane fade" id="measurments">
                    <div class="panel panel-default">
                        <div class="panel-heading">Unit of Measurement (Range)</div>
                        <div class="panel-body">
                            <div class="btn-group" data-toggle="buttons">
                                <label class="btn btn-default<?php ($measurementRange == "imperialNautical" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementRange" id="imperialNautical" value="imperialNautical" autocomplete="off"<?php ($measurementRange == "imperialNautical" ? print ' checked' : ''); ?>> Imperial (Nautical Miles)
                                </label>
                                <label class="btn btn-default<?php ($measurementRange == "imperialStatute" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementRange" id="imperialStatute" value="imperialStatute" autocomplete="off"<?php ($measurementRange == "imperialStatute" ? print ' checked' : ''); ?>> Imperial (Statute Miles)
                                </label>
                                <label class="btn btn-default<?php ($measurementRange == "metric" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementRange" id="metric" value="metric" autocomplete="off"<?php ($measurementRange == "metric" ? print ' checked' : ''); ?>> Metric
                                </label>
                            </div>
                        </div>
                    </div>
                    <div class="panel panel-default">
                        <div class="panel-heading">Unit of Measurement (Temperature)</div>
                        <div class="panel-body">
                            <div class="btn-group" data-toggle="buttons">
                                <label class="btn btn-default<?php ($measurementTemperature == "imperial" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementTemperature" id="imperial" value="imperial" autocomplete="off"<?php ($measurementTemperature == "imperial" ? print ' checked' : ''); ?>> Imperial
                                </label>
                                <label class="btn btn-default<?php ($measurementTemperature == "metric" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementTemperature" id="metric" value="metric" autocomplete="off"<?php ($measurementTemperature == "metric" ? print ' checked' : ''); ?>> Metric
                                </label>
                            </div>
                        </div>
                    </div>
                    <div class="panel panel-default">
                        <div class="panel-heading">Unit of Measurement (Bandwidth)</div>
                        <div class="panel-body">
                            <div class="btn-group" data-toggle="buttons">
                                <label class="btn btn-default<?php ($measurementBandwidth == "kbps" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementBandwidth" id="imperial" value="kbps" autocomplete="off"<?php ($measurementBandwidth == "kbps" ? print ' checked' : ''); ?>> Kbps
                                </label>
                                <label class="btn btn-default<?php ($measurementBandwidth == "mbps" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementBandwidth" id="metric" value="mbps" autocomplete="off"<?php ($measurementBandwidth == "mbps" ? print ' checked' : ''); ?>> Mbps
                                </label>
                            </div>
                        </div>
                    </div>
                </div>
                <div role="tabpanel" class="tab-pane fade" id="system">
                    <div class="panel panel-default">
                        <div class="panel-heading">Network Interface</div>
                        <div class="panel-body">
                            <div class="btn-group" data-toggle="buttons">
                                <label class="btn btn-default<?php ($networkInterface == "eth0" ? print ' active' : ''); ?>">
                                    <input type="radio" name="networkInterface" id="imperial" value="eth0" autocomplete="off"<?php ($networkInterface == "eth0" ? print ' checked' : ''); ?>> eth0
                                </label>
                                <label class="btn btn-default<?php ($networkInterface == "wlan0" ? print ' active' : ''); ?>">
                                    <input type="radio" name="networkInterface" id="metric" value="wlan0" autocomplete="off"<?php ($networkInterface == "wlan0" ? print ' checked' : ''); ?>> wlan0
                                </label>
                            </div>
                        </div>
                    </div>
                </div>
                <div role="tabpanel" class="tab-pane fade" id="maintenance">
                    <div class="panel panel-default">
                        <div class="panel-heading">Purge Positions</div>
                        <div class="panel-body">
                            <p>Current Database Size: <?php echo $common->getDatabaseSize("mb"); ?>MB</p>
                            <div class="form-group">
                                <label for="purgepositionspicker">Purge flight positions old than...</label><br />
                                <input type="text" class="form-control" id="purgepositionspicker" name="purgepositionspicker" autocomplete="off" <?php ($settings::db_driver == "xml" ? print ' disabled' : ''); ?>>
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="purgepositions" value="purge"<?php ($settings::db_driver == "xml" ? print ' disabled' : ''); ?>> Check to confirm purge of data.
                                </label>
                            </div>
                            <script type="text/javascript">
                                jQuery('#purgepositionspicker').datetimepicker({
                                    inline:true
                                });
                            </script>
                        </div>
                    </div>
                </div>
            </div>
            <input type="submit" class="btn btn-default" value="Save Settings">
        </form>
<?php
    require_once('includes/footer.inc.php');
?>
