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

    // The most current stable release.
    $thisVersion = "2.7.1";

    // Begin the upgrade process if this release is newer than what is installed.
    if (file_exists($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php")) {
        require($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
        $common = new common();

        if ($common-> getSetting("version") < $thisVersion) {
            // THis is an older version so forward the user to upgrade.php
            header ("Location: /install/upgrade.php");
        } else {
            // It would appear the this is a current version so forward the user to the index page.
            header ("Location: /");
        }
    }

    // BEGIN FRESH INSTALLATION

    $installed = FALSE;
    //if ($common->postBack()) {
    if (strtoupper($_SERVER['REQUEST_METHOD']) == 'POST') {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."account.class.php");
        $account = new account();

        // Validate the submited form.
        $passwordsMatch = FALSE;
        if ($_POST['password1'] == $_POST['password2'])
            $passwordsMatch = TRUE;

        // Validation passed so continue installation.
        if ($passwordsMatch) {

            // Create database settings variables to handle possible NULL values.
            $dbDatabase = "";
            if (isset($_POST['database']))
                $dbDatabase = $_POST['database'];

            $dbUserName = "";
            if (isset($_POST['username']))
                $dbUserName = $_POST['username'];

            $dbPassword = "";
            if (isset($_POST['password']))
                $dbPassword = $_POST['password'];

            $dbHost = "";
            if (isset($_POST['host']))
                $dbHost = $_POST['host'];
            if ($_POST['driver'] == "sqlite")
                $dbHost = $_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."portal.sqlite";

            $dbPrefix = "adsb_";
            //if (isset($_POST['prefix']))
            //    $dbPrefix = $_POST['prefix'];

            // Create or edit the settings.class.php file.
            $content = <<<EOF
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

    class settings {
        // Database Settings
        const db_driver = '$_POST[driver]';
        const db_database = '$dbDatabase';
        const db_username = '$dbUserName';
        const db_password = '$dbPassword';
        const db_host = '$dbHost';
        const db_prefix = '$dbPrefix';

        // Security Settings
        const sec_length = 6;

        // PDO Settings
        const pdo_debug = TRUE;
    }

?>
EOF;
            file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php", $content);

            require($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
            $common = new common();

            // Setup data storage.
            if ($_POST['driver'] == 'xml') {

                //XML

                // Create XML files used to store administrator data.
                $xml = new XMLWriter();
                $xml->openMemory();
                $xml->setIndent(true);
                $xml->startDocument('1.0','UTF-8');
                $xml->startElement("administrators");
                $xml->endElement();
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml", $xml->flush(true));

                // Create XML files used to store blog post data.
                $xml = new XMLWriter();
                $xml->openMemory();
                $xml->setIndent(true);
                $xml->startDocument('1.0','UTF-8');
                $xml->startElement("blogPosts");
                $xml->endElement();
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml", $xml->flush(true));

                // Create XML files used to store flight notification data.
                $xml = new XMLWriter();
                $xml->openMemory();
                $xml->setIndent(true);
                $xml->startDocument('1.0','UTF-8');
                $xml->startElement("flights");
                $xml->endElement();
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."flightNotifications.xml", $xml->flush(true));

                // Create XML files used to store links data.
                $xml = new XMLWriter();
                $xml->openMemory();
                $xml->setIndent(true);
                $xml->startDocument('1.0','UTF-8');
                $xml->startElement("links");
                $xml->endElement();
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml", $xml->flush(true));

                // Create XML files used to store settings data.
                $xml = new XMLWriter();
                $xml->openMemory();
                $xml->setIndent(true);
                $xml->startDocument('1.0','UTF-8');
                $xml->startElement("settings");
                $xml->endElement();
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."settings.xml", $xml->flush(true));

            } else {

                // PDO
                $dbPrifix = "";
                if (isset($_POST['prefix']))
                    $dbPrifix = $_POST['prefix'];

                // Create database tables.
                switch ($_POST['driver']) {
                    case "mysql":
                        // MySQL
                        $administratorsSql = 'CREATE TABLE '.$dbPrefix.'administrators (
                                                id INT(11) PRIMARY KEY AUTO_INCREMENT,
                                                name VARCHAR(100) NOT NULL,
                                                email VARCHAR(75) NOT NULL,
                                                login VARCHAR(25) NOT NULL,
                                                password VARCHAR(255) NOT NULL,
                                                token VARCHAR(10) NULL);';
                        $aircraftSql = 'CREATE TABLE '.$dbPrefix.'aircraft (
                                          id INT(11) AUTO_INCREMENT PRIMARY KEY,
                                          icao VARCHAR(24) NOT NULL,
                                          firstSeen datetime NOT NULL,
                                          lastSeen datetime NOT NULL);';
                        $blogPostsSql = 'CREATE TABLE '.$dbPrefix.'blogPosts (
                                           id INT(11) PRIMARY KEY AUTO_INCREMENT,
                                           title VARCHAR(100) NOT NULL,
                                           date datetime NOT NULL,
                                           author VARCHAR(100) NOT NULL,
                                           contents VARCHAR(20000) NOT NULL);';
                        $flightsSql = 'CREATE TABLE '.$dbPrefix.'flights(
                                         id INT(11) AUTO_INCREMENT PRIMARY KEY,
                                         aircraft INT(11) NOT NULL,
                                         flight VARCHAR(100) NOT NULL,
                                         firstSeen datetime NOT NULL,
                                         lastSeen datetime NOT NULL);';
                        $linksSql = 'CREATE TABLE '.$dbPrefix.'links(
                                       id INT(11) AUTO_INCREMENT PRIMARY KEY,
                                       name VARCHAR(100) NOT NULL,
                                       address VARCHAR(250) NOT NULL);';
                        $flightNotificationsSql = 'CREATE TABLE '.$dbPrefix.'flightNotifications (
                                                     id INT(11) PRIMARY KEY AUTO_INCREMENT,
                                                     flight VARCHAR(10) NOT NULL);';
                        $positionsSql = 'CREATE TABLE '.$dbPrefix.'positions (
                                           id INT(11) AUTO_INCREMENT PRIMARY KEY,
                                           flight BIGINT NOT NULL,
                                           aircraft BIGINT NOT NULL,
                                           time datetime NOT NULL,
                                           message INT NOT NULL,
                                           squawk INT(4) NULL,
                                           latitude DOUBLE NOT NULL,
                                           longitude DOUBLE NOT NULL,
                                           track INT(11) NOT NULL,
                                           altitude INT(5) NOT NULL,
                                           verticleRate INT(4) NOT NULL,
                                           speed INT(4) NULL);';
                        $settingsSql = 'CREATE TABLE '.$dbPrefix.'settings (
                                          id INT(11) PRIMARY KEY AUTO_INCREMENT,
                                          name VARCHAR(50) NOT NULL,
                                          value VARCHAR(100) NOT NULL);';

                    break;
                    case "pgsql":
                        // PostgreSQL
                        $administratorsSql = 'CREATE TABLE '.$dbPrefix.'administrators (
                                              id SERIAL PRIMARY KEY,
                                              name VARCHAR(100) NOT NULL,
                                              email VARCHAR(75) NOT NULL,
                                              login VARCHAR(25) NOT NULL,
                                              password VARCHAR(255) NOT NULL,
                                              token VARCHAR(10) NULL);';
                        $aircraftSql = 'CREATE TABLE '.$dbPrefix.'aircraft (
                                          id SERIAL PRIMARY KEY,
                                          icao VARCHAR(24) NOT NULL,
                                          firstSeen VARCHAR(100) NOT NULL,
                                          lastSeen VARCHAR(100) NOT NULL);';
                        $blogPostsSql = 'CREATE TABLE '.$dbPrefix.'blogPosts (
                                         id SERIAL PRIMARY KEY,
                                         title VARCHAR(100) NOT NULL,
                                         date VARCHAR(20) NOT NULL,
                                         author VARCHAR(100) NOT NULL,
                                         contents VARCHAR(20000) NOT NULL);';
                        $flightsSql = 'CREATE TABLE '.$dbPrefix.'flights (
                                         id SERIAL PRIMARY KEY,
                                         aircraft INT(11) NOT NULL,
                                         flight VARCHAR(100) NOT NULL,
                                         firstSeen VARCHAR(100) NOT NULL,
                                         lastSeen VARCHAR(100) NOT NULL);';
                        $linksSql = 'CREATE TABLE '.$dbPrefix.'links(
                                       id INT(11) AUTO_INCREMENT PRIMARY KEY,
                                       name VARCHAR(100) NOT NULL,
                                       address VARCHAR(250) NOT NULL);';
                        $flightNotificationsSql = 'CREATE TABLE '.$dbPrefix.'flightNotifications (
                                                   id SERIAL PRIMARY KEY,
                                                   flight VARCHAR(10) NOT NULL);';
                        $positionsSql = 'CREATE TABLE '.$dbPrefix.'positions (
                                           id SERIAL PRIMARY KEY,
                                           flight BIGINT NOT NULL,
                                           aircraft BIGINT NOT NULL,
                                           time VARCHAR(100) NOT NULL,
                                           message INT NOT NULL,
                                           squawk INT(4) NULL,
                                           latitude DOUBLE NOT NULL,
                                           longitude DOUBLE NOT NULL,
                                           track INT(11) NOT NULL,
                                           altitude INT(5) NOT NULL,
                                           verticleRate INT(4) NOT NULL,
                                           speed INT(4) NULL);';
                        $settingsSql = 'CREATE TABLE '.$dbPrefix.'settings (
                                        id SERIAL PRIMARY KEY,
                                        name VARCHAR(50) NOT NULL,
                                        value VARCHAR(100) NOT NULL);';
                    break;
                    case "sqlite":
                        // SQLite
                        $administratorsSql = 'CREATE TABLE '.$dbPrefix.'administrators (
                                              id INTEGER PRIMARY KEY AUTOINCREMENT,
                                              name TEXT NOT NULL,
                                              email TEXT NOT NULL,
                                              login TEXT NOT NULL,
                                              password TEXT NOT NULL,
                                              token TEXT NULL);';
                        $aircraftSql = 'CREATE TABLE '.$dbPrefix.'aircraft (
                                          id INTEGER PRIMARY KEY AUTOINCREMENT,
                                          icao TEXT NOT NULL,
                                          firstSeen DATETIME NOT NULL,
                                          lastSeen DATETIME NOT NULL);';
                        $blogPostsSql = 'CREATE TABLE '.$dbPrefix.'blogPosts (
                                         id INTEGER PRIMARY KEY AUTOINCREMENT,
                                         title TEXT NOT NULL,
                                         date DATETIME NOT NULL,
                                         author TEXT NOT NULL,
                                         contents TEXT NOT NULL);';
                        $flightsSql = 'CREATE TABLE '.$dbPrefix.'flights (
                                         id INTEGER PRIMARY KEY AUTOINCREMENT,
                                         aircraft INTEGER NOT NULL,
                                         flight TEXT NOT NULL,
                                         firstSeen DATETIME NOT NULL,
                                         lastSeen DATETIME NOT NULL);';
                        $linksSql = 'CREATE TABLE '.$dbPrefix.'links(
                                       id INTEGER PRIMARY KEY AUTOINCREMENT,
                                       name TEXT NOT NULL,
                                       address TEXT NOT NULL);';
                        $flightNotificationsSql = 'CREATE TABLE '.$dbPrefix.'flightNotifications (
                                                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                                                   flight TEXT NOT NULL);';
                        $positionsSql = 'CREATE TABLE '.$dbPrefix.'positions (
                                           id INTEGER PRIMARY KEY AUTOINCREMENT,
                                           flight INTEGER NOT NULL,
                                           aircraft INTEGER NOT NULL,
                                           time DATETIME NOT NULL,
                                           message INTEGER NOT NULL,
                                           squawk INTEGER NULL,
                                           latitude INTEGER NOT NULL,
                                           longitude INTEGER NOT NULL,
                                           track INTEGER NOT NULL,
                                           altitude INTEGER NOT NULL,
                                           verticleRate INTEGER NOT NULL,
                                           speed INTEGER NULL);';
                        $settingsSql = 'CREATE TABLE '.$dbPrefix.'settings (
                                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                                        name TEXT NOT NULL,
                                        value TEXT NOT NULL);';
                    break;
                }

                $dbh = $common->pdoOpen();

                // Set permissions on SQLite file.
                if ($_POST['driver'] == "sqlite") {
                    chmod($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."portal.sqlite", 0666);
                }

                $sth = $dbh->prepare($administratorsSql);
                $sth->execute();
                $sth = NULL;

                $sth = $dbh->prepare($aircraftSql);
                $sth->execute();
                $sth = NULL;

                $sth = $dbh->prepare($blogPostsSql);
                $sth->execute();
                $sth = NULL;

                $sth = $dbh->prepare($flightsSql);
                $sth->execute();
                $sth = NULL;

                $sth = $dbh->prepare($linksSql);
                $sth->execute();
                $sth = NULL;

                $sth = $dbh->prepare($flightNotificationsSql);
                $sth->execute();
                $sth = NULL;

                $sth = $dbh->prepare($positionsSql);
                $sth->execute();
                $sth = NULL;

                $sth = $dbh->prepare($settingsSql);
                $sth->execute();
                $sth = NULL;

                $dbh = NULL;
            }


            // Add settings.
            $common->addSetting('version', $thisVersion);
            $common->addSetting('patch', '');
            $common->addSetting('siteName', 'ADS-B Receiver');
            $common->addSetting('template', 'default');
            $common->addSetting('defaultPage', 'blog.php');
            $common->addSetting('dateFormat', 'F jS, Y g:i A');
            $common->addSetting('enableBlog', TRUE);
            $common->addSetting('enableInfo', TRUE);
            $common->addSetting('enableLinks', FALSE);
            $common->addSetting('enableGraphs', TRUE);
            $common->addSetting('enableDump1090', TRUE);
            $common->addSetting('enableDump978', FALSE);
            $common->addSetting('enablePfclient', FALSE);
            $common->addSetting('enableFlightAwareLink', FALSE);
            $common->addSetting('flightAwareLogin', '');
            $common->addSetting('flightAwareSite', '');
            $common->addSetting('enablePlaneFinderLink', FALSE);
            $common->addSetting('planeFinderReceiver', '');
            $common->addSetting('enableFlightRadar24Link', '');
            $common->addSetting('flightRadar24Id', '');
            $common->addSetting('enableAdsbExchangeLink', FALSE);
            $common->addSetting('measurementRange', 'imperialNautical');
            $common->addSetting('measurementTemperature', 'imperial');
            $common->addSetting('measurementBandwidth', 'mbps');
            $common->addSetting('networkInterface', 'eth0');
            $common->addSetting('emailFrom', 'noreply@adsbreceiver.net');
            $common->addSetting('emailReplyTo', 'noreply@adsbreceiver.net');
            $common->addSetting('timeZone', $_POST['timeZone']);
            $common->addSetting('enableWebNotifications', FALSE);
            $common->addSetting('googleMapsApiKey', '');
            $common->addSetting("hideNavbarAndFooter", FALSE);
            $common->addSetting("purgeAircraft", FALSE);

            if ($_POST['driver'] == "xml")
                $common->addSetting('enableFlights', FALSE);
            else
                $common->addSetting('enableFlights', TRUE);

            // Add the administrator account.
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."account.class.php");
            $account->addAdministrator($_POST['name'], $_POST['email'], $_POST['login'], password_hash($_POST['password1'], PASSWORD_DEFAULT));

            // Mark the installation as complete.
            $installed = TRUE;
        }
    }

    // Check Folder and File Permissions
    ///////////////////////////////////////

    $applicationDirectory = preg_replace( '~[/\\\\][^/\\\\]*$~', DIRECTORY_SEPARATOR, getcwd());

    $writableData = FALSE;
    if (is_writable($applicationDirectory.'data'))
        $writableData = TRUE;

    $writeableClasses = FALSE;
    if (is_writable($applicationDirectory.'classes'))
        $writeableClasses = TRUE;

    // Function used to format offsets of timezones.
    ///////////////////////////////////////////////////

    function formatOffset($offset) {
        return sprintf('%+03d:%02u', floor($offset / 3600), floor(abs($offset) % 3600 / 60));
    }
    $utc = new DateTimeZone('UTC');
    $dt = new DateTime('now', $utc);

    // Display HTML
    //////////////////

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");

    // Display the instalation wizard.
    if (!$installed) {
?>
<link rel="stylesheet" href="/admin/assets/css/jquery.steps.css">
<link rel="stylesheet" href="/admin/assets/css/install.css">
<script src="/admin/assets/js/jquery.steps.min.js"></script>
<script src="/admin/assets/js/js.cookie-2.1.3.min.js"></script>
<script src="/admin/assets/js/jquery.validate.min.js"></script>
<script src="/admin/assets/js/install.js"></script>

<h1>ADS-B Receiver Portal Setup</h1>
<p>The following wizard will guide you through the setup process.</p>
<div class="padding"></div>
<form id="install-form" method="post" action="index.php">
    <div class="form-group">

        <h2>Directory Permissions</h2>
        <section>
            <div class="alert <?php echo ($writableData == TRUE ? 'alert-success' : 'alert-danger' ); ?>">The <strong>data</strong> directory is<?php echo ($writableData ? ' ' : ' not' ); ?> writable.</div>
            <div class="alert <?php echo ($writeableClasses ? 'alert-success' : 'alert-danger' ); ?>">The <strong>classes</strong> directory is<?php echo ($writeableClasses ? ' ' : ' not' ); ?> writable.</div>
            <input type="hidden" name="permissions" id="permissions" value="<?php echo $writableData; ?>">
<?php if (!$writableData || !$writeableClasses) {?>
            <p>
                Please fix the permissions for the following directory and/or file to make sure they are writable before proceeding.
                Once you have made the necessary changes please <a href="#" onclick="location.reload();">reload</a> this page to allow the installer to recheck permissions.
            </p>
<?php } ?>
        </section>

        <h2>Data Storage</h2>
        <section>
            <label for="driver">Database Type</label>
            <select class="form-control" name="driver" id="driver">
                <option value="xml">XML (Lite installation only)</option>
                <option value="mysql">MySQL (Advanced installation only)</option>
                <option value="sqlite">SQLite (Advanced installation only)</option>
            </select>
            <div class="form-group" id="host-div">
                <label for="host">Database Server *</label>
                <input type="text" class="form-control" name="host" id="host" required>
            </div>
            <div class="form-group" id="username-div">
                <label for="username">Database User *</label>
                <input type="text" class="form-control" name="username" id="username" required>
            </div>
            <div class="form-group" id="password-div">
                <label for="password">Database Password *</label>
                <input type="password" class="form-control" name="password" id="password" required>
            </div>
            <div class="form-group" id="database-div">
                <label for="database" id="database-name">Database Name *</label>
                <input type="text" class="form-control" name="database" id="database" required>
            </div>
            <div class="form-group" id="prefix-div">
                <label for="prefix">Database Prefix</label>
                <input type="text" class="form-control" name="prefix" id="prefix" id="prefix" value="adsb_" readonly>
            </div>
            <p id="required-p">(*) Required</p>
        </section>

        <h2>Portal Settings</h2>
        <section>
            <div class="form-group">
                <label for="timeZone">Time Zone</label>
                <select class="form-control" id="timeZone" name="timeZone">
<?php
    foreach (DateTimeZone::listIdentifiers() as $timeZone) {
        $currentTimeZone = new DateTimeZone($timeZone);
        $offSet = $currentTimeZone->getOffset($dt);
        $transition = $currentTimeZone->getTransitions($dt->getTimestamp(), $dt->getTimeStamp());
        $abbr = $transition[0]['abbr'];
        echo '<option name="timeZone" value="'.$timeZone.'">'.$timeZone.' ['.$abbr.' '.formatOffset($offSet).']</option>';
    }
?>
                </select>
            </div>
        </section>

        <h2>Administrator Account</h2>
        <section>
            <div class="form-group">
                <label for="adminName">Administrator Name *</label>
                <input type="text" class="form-control" name="name" required>
            </div>
            <div class="form-group">
                <label for="adminEmail">Administrator Email Address *</label>
                <input type="email" class="form-control" name="email" required>
            </div>
            <div class="form-group">
                <label for="AdminLogin">Administrator Login *</label>
                <input type="text" class="form-control" name="login" required>
            </div>
            <div class="form-group">
                <label for="adminPassword1">Administrator Password *</label> <span id="result"></span>
                <input type="password" class="form-control" class="form-control" name="password1" id="password1" required>
            </div>
            <div class="form-group">
                <label for="adminPassword2">Repeat Password *</label>
                <input type="password" class="form-control" name="password2" id="password2" required>
            </div>
            <p>(*) Required</p>
        </section>
    </div>
</form>

<?php
    } else {
?>
<h1>ADS-B Receiver Portal Setup</h1>
<p>Setup of your ADS-B Receiver Web Portal is now complete.</p>
<p>
    For security reasons it is highly recommended that the installation files be deleted permanently from your device.
    At this time you should also ensure that the file containing the settings you specified is no longer writeable.
    Please log into your device and run the following commands to accomplish these tasks.
</p>
<pre>sudo rm -rf <?php echo $_SERVER["DOCUMENT_ROOT"]; ?>/install/</pre>
<pre>sudo chmod -w <?php echo $_SERVER["DOCUMENT_ROOT"]; ?>/classes/settings.class.php</pre>
<p>Once you have done so you can log in and administrate your portal <a href="/admin/">here</a>.</p>
<p>
    If you experienced any issues or have any questions or suggestions you would like to make regarding this project
    feel free to do so on the projects homepage located at <a href="https://www.adsbreceiver.net">https://www.adsbreceiver.net</a>.
</p>
<?php
    }
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>
