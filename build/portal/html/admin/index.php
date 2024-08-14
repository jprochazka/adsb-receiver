<?php
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
        $flightNotificationArray = explode(',', $_POST['flightNotifications']);

        if ($settings::db_driver == "xml") {
            // XML
            $flightNotifications = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."flightNotifications.xml");
            unset($flightNotifications->flight);
            foreach ($flightNotificationArray as $flightNotification) {
                $newFlightNotification = $flightNotifications->addChild('flight', $flightNotification);
                $dom = dom_import_simplexml($flightNotifications)->ownerDocument;
                $dom->formatOutput = TRUE;
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."flightNotifications.xml", $dom->saveXML());
            }
        } else {
            // PDO
            $dbh = $common->pdoOpen();
            $sql = "SELECT * FROM ".$settings::db_prefix."flightNotifications";
            $sth = $dbh->prepare($sql);
            $sth->execute();
            $savedFlights = $sth->fetchAll();
            $sth = NULL;
            $dbh = NULL;
            foreach ($savedFlights as $flight) {
                // Remove flight if not in list.
                if (!in_array($flight, $notificationArray ?? [])) {
                    $dbh = $common->pdoOpen();
                    $sql = "DELETE FROM ".$settings::db_prefix."flightNotifications WHERE flight = :flight";
                    $sth = $dbh->prepare($sql);
                    $sth->bindParam(':flight', $flight['flight'], PDO::PARAM_STR, 10);
                    $sth->execute();
                    $sth = NULL;
                    $dbh = NULL;
                }
            }
            foreach ($flightNotificationArray as $flight) {
                // Add flight if not saved already.
                if (!in_array($flight, $savedFlights)) {
                    $dbh = $common->pdoOpen();
                    $sql = "INSERT INTO ".$settings::db_prefix."flightNotifications (flight) VALUES (:flight)";
                    $sth = $dbh->prepare($sql);
                    $sth->bindParam(':flight', $flight, PDO::PARAM_STR, 10);
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

        $enableAcars = FALSE;
        if (isset($_POST['enableAcars']) && $_POST['enableAcars'] == "TRUE")
            $enableAcars = TRUE;

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

        $hideNavbarAndFooter = FALSE;
         if (isset($_POST['hideNavbarAndFooter']) && $_POST['hideNavbarAndFooter'] == "TRUE")
            $hideNavbarAndFooter = TRUE;

        $purgeOlderData = FALSE;
         if (isset($_POST['purgeOlderData']) && $_POST['purgeOlderData'] == "TRUE")
            $purgeOlderData = TRUE;

        // Update settings using those supplied by the form.
        $common->updateSetting("siteName", $_POST['siteName']);
        $common->updateSetting("template", $_POST['template']);
        $common->updateSetting("defaultPage", $_POST['defaultPage']);
        $common->updateSetting("dateFormat", $_POST['dateFormat']);
        $common->updateSetting("enableFlights", $enableFlights);
        $common->updateSetting("enableBlog", $enableBlog);
        $common->updateSetting("enableAcars", $enableAcars);
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
        $common->updateSetting("googleMapsApiKey", $_POST['googleMapsApiKey']);
        $common->updateSetting("hideNavbarAndFooter", $hideNavbarAndFooter);
        $common->updateSetting("purge_older_data", $purgeOlderData);
        $common->updateSetting("days_to_save", $_POST['daysToSave']);
        $common->updateSetting("acarsserv_database", $_POST['acarsservDatabase']);

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
    $flightNotifications = NULL;
    $savedFlights = array();
    if ($settings::db_driver == "xml") {
        // XML
        $savedFlights = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."flightNotifications.xml");
        foreach ($savedFlights as $savedFlight) {
            $flightNotifications = ltrim($flightNotifications.",".$savedFlight, ',');
        }
    } else {
        //PDO
        $dbh = $common->pdoOpen();
        $sql = "SELECT * FROM ".$settings::db_prefix."flightNotifications";
        $sth = $dbh->prepare($sql);
        $sth->execute();
        $savedFlights = $sth->fetchAll();
        $sth = NULL;
        $dbh = NULL;
        foreach ($savedFlights as $savedFlight) {
            $flightNotifications = ltrim($flightNotifications.",".$savedFlight['flight'], ',');
        }
    }
    $enableWebNotifications = $common->getSetting("enableWebNotifications");

    // Get general settings.
    $siteName = $common->getSetting("siteName");
    $currentTemplate = $common->getSetting("template");
    $defaultPage = $common->getSetting("defaultPage");
    $dateFormat = $common->getSetting("dateFormat");
    $timeZone = $common->getSetting("timeZone");
    $googleMapsApiKey = $common->getSetting("googleMapsApiKey");

    // Get navigation settings.
    $enableFlights = $common->getSetting("enableFlights");
    $enableBlog = $common->getSetting("enableBlog");
    $enableAcars = $common->getSetting("enableAcars");
    $enableInfo = $common->getSetting("enableInfo");
    $enableGraphs = $common->getSetting("enableGraphs");
    $enableLinks = $common->getSetting("enableLinks");
    $enableDump1090 = $common->getSetting("enableDump1090");
    $enableDump978 = $common->getSetting("enableDump978");
    $enablePfclient = $common->getSetting("enablePfclient");
    $hideNavbarAndFooter = $common->getSetting("hideNavbarAndFooter");

    // Get aggregate site settings.
    $enableFlightAwareLink = $common->getSetting("enableFlightAwareLink");
    $flightAwareLogin = $common->getSetting("flightAwareLogin");
    $flightAwareSite = $common->getSetting("flightAwareSite");
    $enablePlaneFinderLink = $common->getSetting("enablePlaneFinderLink");
    $planeFinderReceiver = $common->getSetting("planeFinderReceiver");
    $enableFlightRadar24Link = $common->getSetting("enableFlightRadar24Link");
    $flightRadar24Id = $common->getSetting("flightRadar24Id");
    $enableAdsbExchangeLink = $common->getSetting("enableAdsbExchangeLink");

    // ACARS settings.
    $acarsservDatabase = $common->getSetting("acarsserv_database");

    // Get units of measurement settings.
    $measurementRange = $common->getSetting("measurementRange");
    $measurementTemperature = $common->getSetting("measurementTemperature");
    $measurementBandwidth = $common->getSetting("measurementBandwidth");

    // Get the network interface settings.
    $networkInterface = $common->getSetting("networkInterface");

    // Get data purge settings.
    $purgeOlderData = $common->getSetting("purge_older_data");
    $daysToSave = $common->getSetting("days_to_save");

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

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");

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
                <li role="presentation"><a href="#measurements" aria-controls="measurements" role="tab" data-toggle="tab">Measurements</a></li>
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
                                <label for="googleMapsApiKey">Google Maps API Key</label>
                                <input type="text" class="form-control" id="googleMapsApiKey" name="googleMapsApiKey" value="<?php echo $googleMapsApiKey; ?>">
                            </div>
                        </div>
                    </div>
                    <div class="panel panel-default">
                        <div class="panel-heading">Time Format</div>
                        <div class="panel-body">
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
                                <label for="defaultPage">Date Format - 12 Hour Format</label>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="F jS, Y g:i A"<?php ($dateFormat == "F jS, Y g:i A" ? print ' checked' : ''); ?>>October 16, 2015 5:00 PM</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="Y-m-d g:i A"<?php ($dateFormat == "Y-m-d g:i A" ? print ' checked' : ''); ?>>2015-10-16 5:00 PM</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="m/d/Y g:i A"<?php ($dateFormat == "m/d/Y g:i A" ? print ' checked' : ''); ?>>10/16/2015 5:00 PM</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="d/m/Y g:i A"<?php ($dateFormat == "d/m/Y g:i A" ? print ' checked' : ''); ?>>16/10/2015 5:00 PM</label>
                                </div>
                                <label for="defaultPage">Date Format - 24 Hour Format</label>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="F jS, Y G:i"<?php ($dateFormat == "F jS, Y G:i" ? print ' checked' : ''); ?>>October 16, 2015 17:00</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="Y-m-d G:i"<?php ($dateFormat == "Y-m-d G:i" ? print ' checked' : ''); ?>>2015-10-16 17:00</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="m/d/Y G:i"<?php ($dateFormat == "m/d/Y G:i" ? print ' checked' : ''); ?>>10/16/2015 17:00</label>
                                </div>
                                <div class="radio">
                                    <label><input type="radio" name="dateFormatSlelection" value="d/m/Y G:i"<?php ($dateFormat == "d/m/Y G:i" ? print ' checked' : ''); ?>>16/10/2015 17:00</label>
                                </div>
                                <label for="dateFormat">Date Format</label>
                                <input type="text" class="form-control" id="dateFormat" name="dateFormat" value="<?php echo $dateFormat; ?>">
                                <p><i>Select one of the formats above or create your own. <a href="http://php.net/manual/en/function.date.php" target="_blank">PHP date function documentation.</a></i></p>
                            </div>
                        </div>
                    </div>
                </div>
                <div role="tabpanel" class="tab-pane fade" id="notifications">
                    <div class="panel panel-default">
                        <div class="panel-heading">Flight Notifications</div>
                        <div class="panel-body">
                            <div class="form-group">
                                <label for="flightNotifications">Flight names. (coma delimited)</label>
                                <input type="text" class="form-control" id="flightNotifications" name="flightNotifications" value="<?php echo $flightNotifications; ?>">
                            </div>
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="enableWebNotifications" value="TRUE"<?php ($enableWebNotifications == 1 ? print ' checked' : ''); ?>> Enable web based flight notifications.
                                </label>
                            </div>
                        </div>
                    </div>
                </div>
                <div role="tabpanel" class="tab-pane fade" id="navigation">
                    <div class="panel panel-default">
                        <div class="panel-heading">Navigation Settings</div>
                        <div class="panel-body">
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" name="hideNavbarAndFooter" value="TRUE"<?php ($hideNavbarAndFooter == 1 ? print ' checked' : ''); ?>> Enable navigation and footer auto hiding.
                                </label>
                            </div>
                            <br />
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
                                    <input type="checkbox" name="enableAcars" value="TRUE"<?php ($enableAcars == 1? print ' checked' : ''); ?>> Enable ACARS link.
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
                    <div class="panel panel-default">
                        <div class="panel-heading">ACARS Settings</div>
                        <div class="panel-body">
                            <div class="form-group">
                                <label for="acarsservDatabase">ACARSSERV Database Path</label>
                                <input type="text" class="form-control" id="acarsservDatabase" name="acarsservDatabase" value="<?php echo $acarsservDatabase; ?>">
                            </div>
                        </div>
                    </div>
                </div>
                <div role="tabpanel" class="tab-pane fade" id="measurements">
                    <div class="panel panel-default">
                        <div class="panel-heading">Unit of Measurement (Range)</div>
                        <div class="panel-body">
                            <div class="btn-group" data-toggle="buttons">
                                <label class="btn btn-default<?php ($measurementRange == "imperialNautical" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementRange" id="imperialNautical" value="imperialNautical"<?php ($measurementRange == "imperialNautical" ? print ' checked' : ''); ?>> Imperial (Nautical Miles)
                                </label>
                                <label class="btn btn-default<?php ($measurementRange == "imperialStatute" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementRange" id="imperialStatute" value="imperialStatute"<?php ($measurementRange == "imperialStatute" ? print ' checked' : ''); ?>> Imperial (Statute Miles)
                                </label>
                                <label class="btn btn-default<?php ($measurementRange == "metric" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementRange" id="metric" value="metric"<?php ($measurementRange == "metric" ? print ' checked' : ''); ?>> Metric
                                </label>
                            </div>
                        </div>
                    </div>
                    <div class="panel panel-default">
                        <div class="panel-heading">Unit of Measurement (Temperature)</div>
                        <div class="panel-body">
                            <div class="btn-group" data-toggle="buttons">
                                <label class="btn btn-default<?php ($measurementTemperature == "imperial" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementTemperature" id="imperial" value="imperial"<?php ($measurementTemperature == "imperial" ? print ' checked' : ''); ?>> Imperial
                                </label>
                                <label class="btn btn-default<?php ($measurementTemperature == "metric" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementTemperature" id="metric" value="metric"<?php ($measurementTemperature == "metric" ? print ' checked' : ''); ?>> Metric
                                </label>
                            </div>
                        </div>
                    </div>
                    <div class="panel panel-default">
                        <div class="panel-heading">Unit of Measurement (Bandwidth)</div>
                        <div class="panel-body">
                            <div class="btn-group" data-toggle="buttons">
                                <label class="btn btn-default<?php ($measurementBandwidth == "kbps" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementBandwidth" id="imperial" value="kbps"<?php ($measurementBandwidth == "kbps" ? print ' checked' : ''); ?>> Kbps
                                </label>
                                <label class="btn btn-default<?php ($measurementBandwidth == "mbps" ? print ' active' : ''); ?>">
                                    <input type="radio" name="measurementBandwidth" id="metric" value="mbps"<?php ($measurementBandwidth == "mbps" ? print ' checked' : ''); ?>> Mbps
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
                                    <input type="radio" name="networkInterface" id="eth0" value="eth0"<?php ($networkInterface == "eth0" ? print ' checked' : ''); ?>> eth0
                                </label>
                                <label class="btn btn-default<?php ($networkInterface == "eno1" ? print ' active' : ''); ?>">
                                    <input type="radio" name="networkInterface" id="eno1" value="eno1"<?php ($networkInterface == "eno1" ? print ' checked' : ''); ?>> eno1
                                </label>
                                <label class="btn btn-default<?php ($networkInterface == "wlan0" ? print ' active' : ''); ?>">
                                    <input type="radio" name="networkInterface" id="wlan0" value="wlan0"<?php ($networkInterface == "wlan0" ? print ' checked' : ''); ?>> wlan0
                                </label>
                                <label class="btn btn-default<?php ($networkInterface == "wlo1" ? print ' active' : ''); ?>">
                                    <input type="radio" name="networkInterface" id="wlo1" value="wlo1"<?php ($networkInterface == "wlo1" ? print ' checked' : ''); ?>> wlo1
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
                            <div class="checkbox">
                                <label>
                                    <input type="checkbox" id="purgeOlderData" name="purgeOlderData" value="TRUE"<?php ($purgeOlderData == 1 ? print ' checked' : ''); ?><?php ($settings::db_driver == "xml" ? print ' disabled' : ''); ?>> Enable daily purges of older flight data.
                                </label>
                            </div>
                            <div class="form-group">
                                <label for="daystosave"">Keep only data newer than X days.</label>
                                <input type="text" class="form-control" id="daysToSave" name="daysToSave" value="<?php echo $daysToSave; ?>"<?php ($settings::db_driver == "xml" ? print ' disabled' : ''); ?>>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <input type="submit" class="btn btn-default" value="Save Settings">
        </form>
<?php
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>
