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

    session_start();

    // Load the require PHP classes.
    require_once('classes/common.class.php');
    require_once('classes/account.class.php');

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
        // Set TRUE or FALSE for checkbox items.
        $enableInfo = FALSE;
        if (isset($_POST['enableInfo']) && $_POST['enableInfo'] == "TRUE")
            $enableInfo = TRUE;

        $enableGraphs = FALSE;
        if (isset($_POST['enableGraphs']) && $_POST['enableGraphs'] == "TRUE")
            $enableGraphs = TRUE;

        $enableDump1090 = FALSE;
        if (isset($_POST['enableDump1090']) && $_POST['enableDump1090'] == "TRUE")
            $enableDump1090 = TRUE;

        $enableDump978 = FALSE;
        if (isset($_POST['enableDump978']) && $_POST['enableDump978'] == "TRUE")
            $enableDump978 = TRUE;

        $enablePfclient = FALSE;
        if (isset($_POST['enablePfclient']) && $_POST['enablePfclient'] == "TRUE")
            $enablePfclient = TRUE;

        // Update settings using those supplied byt the form.
        $common->updateSetting("siteName", $_POST['siteName']);
        $common->updateSetting("template", $_POST['template']);
        $common->updateSetting("defaultPage", $_POST['defaultPage']);
        $common->updateSetting("enableInfo", $enableInfo);
        $common->updateSetting("enableGraphs", $enableGraphs);
        $common->updateSetting("enableDump1090", $enableDump1090);
        $common->updateSetting("enableDump978", $enableDump978);
        $common->updateSetting("enablePfclient", $enablePfclient);
        $common->updateSetting("measurement", $_POST['measurement']);
        $common->updateSetting("networkInterface", $_POST['networkInterface']);

        // Set updated to TRUE since settings were updated.
        $updated = TRUE;
    }

    // Get general settings from settings.xml.
    $siteName = $common->getSetting("siteName");
    $currentTemplate = $common->getSetting("template");
    $defaultPage = $common->getSetting("defaultPage");

    // Get navigation settings from settings.xml.
    $enableInfo = $common->getSetting("enableInfo");
    $enableGraphs = $common->getSetting("enableGraphs");
    $enableDump1090 = $common->getSetting("enableDump1090");
    $enableDump978 = $common->getSetting("enableDump978");
    $enablePfclient = $common->getSetting("enablePfclient");

    // Get unit of measurement setting from settings.xml.
    $measurement = $common->getSetting("measurement");

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
            <div class="panel panel-default">
                <div class="panel-heading">General Settings</div>
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
                            <option value="system.php"<?php ($defaultPage == "system.php" ? print ' selected' : ''); ?>>System Information</option>
                            <option value="graphs.php"<?php ($defaultPage == "graphs.php" ? print ' selected' : ''); ?>>Performance Graphs</option>
                            <option value="dump1090.php"<?php ($defaultPage == "dump1090.php" ? print ' selected' : ''); ?>>Live Dump1090 Map</option>
                            <option value="dump978.php"<?php ($defaultPage == "dump978.php" ? print ' selected' : ''); ?>>Live Dump978 Map</option>
                        </select>
                    </div>
                </div>
            </div>
            <div class="panel panel-default">
                <div class="panel-heading">Navigation Settings</div>
                <div class="panel-body">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="enableInfo" value="TRUE"<?php ($enableInfo == 1 ? print ' checked' : ''); ?>> Enable system information link.
                        </label>
                    </div>
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="enableGraphs" value="TRUE"<?php ($enableGraphs == 1 ? print ' checked' : ''); ?>> Enable performance graphs link.
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
                            <input type="checkbox" name="enablePfclient" value="TRUE"<?php ($enablePfclient == 1 ? print ' checked' : ''); ?>> Enable Planfinder ADS-B Client link.
                        </label>
                    </div>
                </div>
            </div>
            <div class="panel panel-default">
                <div class="panel-heading">Unit of Measurement</div>
                <div class="panel-body">
                    <div class="btn-group" data-toggle="buttons">
                        <label class="btn btn-default<?php ($measurement == "imperial" ? print ' active' : ''); ?>">
                            <input type="radio" name="measurement" id="imperial" value="imperial" autocomplete="off"<?php ($measurement == "imperial" ? print ' checked' : ''); ?>> Imperial
                        </label>
                        <label class="btn btn-default<?php ($measurement == "metric" ? print ' active' : ''); ?>">
                            <input type="radio" name="measurement" id="metric" value="metric" autocomplete="off"<?php ($measurement == "metric" ? print ' checked' : ''); ?>> Metric
                        </label>
                    </div>
                </div>
            </div>
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
            <input type="submit" class="btn btn-default" value="Save Settings">
        </form>
<?php
    require_once('includes/footer.inc.php')
?>
