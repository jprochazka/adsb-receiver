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

    require_once('../classes/common.class.php');
    require_once('../classes/settings.class.php');

    $common = new common();
    $settings = new settings();

    // The most current stable release.
    $thisVersion = "2.3.0";

    // Begin the upgrade process if this release is newer than what is installed.
    if ($common->getSetting("version") == $thisVersion) {
        header ("Location: /");
    }

    $error = FALSE;
    #errorMessage = "No error message returned.";

    ///////////////////////
    // UPGRADE TO V2.0.1
    ///////////////////////

    if ($common->getSetting("version") == "2.0.0") {
        try {
            // Change tables containing datetime data to datetime.
            if ($settings::db_driver != "xml") {

                // Alter MySQL tables.
                if ($settings::db_driver != "mysql") {
                    $dbh = $common->pdoOpen();

                    $sql = "ALTER TABLE ".$settings::db_prefix."aircraft MODIFY firstSeen DATETIME NOT NULL";
                    $sth = $dbh->prepare($sql);
                    $sth->execute();
                    $sth = NULL;

                    $sql = "ALTER TABLE adsb_aircraft MODIFY lastSeen DATETIME NOT NULL";
                    $sth = $dbh->prepare($sql);
                    $sth->execute();
                    $sth = NULL;

                    $sql = "ALTER TABLE adsb_blogPosts MODIFY date DATETIME NOT NULL";
                    $sth = $dbh->prepare($sql);
                    $sth->execute();
                    $sth = NULL;

                    $sql = "ALTER TABLE adsb_flights MODIFY firstSeen DATETIME NOT NULL";
                    $sth = $dbh->prepare($sql);
                    $sth->execute();
                    $sth = NULL;

                    $sql = "ALTER TABLE adsb_flights MODIFY firstSeen DATETIME NOT NULL";
                    $sth = $dbh->prepare($sql);
                    $sth->execute();
                    $sth = NULL;

                    $sql = "ALTER TABLE adsb_positions MODIFY time DATETIME NOT NULL";
                    $sth = $dbh->prepare($sql);
                    $sth->execute();
                    $sth = NULL;

                    $dbh = NULL;
                }
            }

            // Add timezone setting.
            $common->addSetting("timeZone", date_default_timezone_get());

            // update version and patch settings.
            $common->updateSetting("version", "2.0.1");
            $common->updateSetting("patch", "");
        } catch(Exception $e) {
            $error = TRUE;
            $errorMessage = $e->getMessage();
        }
    }

    ///////////////////////
    // UPGRADE TO V2.0.2
    ///////////////////////

    if ($common->getSetting("version") == "2.0.1") {
        try {

            // Set proper permissions on the SQLite file.
            if ($settings::db_driver == "sqlite") {
                chmod($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."portal.sqlite", 0666);
            }

            $common->updateSetting("version", "2.0.2");
            $common->updateSetting("patch", "");
        } catch(Exception $e) {
            $error = TRUE;
            $errorMessage = $e->getMessage();
        }
    }

    ///////////////////////
    // UPGRADE RO V2.0.3
    ///////////////////////

    if ($common->getSetting("version") == "2.0.2") {
        try {
            $common->updateSetting("version", "2.0.3");
            $common->updateSetting("patch", "");
        } catch(Exception $e) {
            $error = TRUE;
            $errorMessage = $e->getMessage();
        }
    }

    ///////////////////////
    // UPGRADE TO V2.1.0
    ///////////////////////

    if ($common->getSetting("version") == "2.0.3") {
        try {

            // Add the positions.aircraft column if using "SQL" storage.
            if ($settings::db_driver != "xml") {

                if ($settings::db_driver == "sqlite") {
                    // In SQLite aircraft.flight should have been an INTEGER not TEXT column.
                    // Since SQLite does not fully support ALTER TABLE allowing the change to be done easily this change will be skipped.
                    // This change will be addressed in the future if a problem arises with this column not being specifed as an INTEGER.
                }

                if ($settings::db_driver == "mysql") {
                    // Check to see if the column already exists.
                    $dbh = $common->pdoOpen();
                    if (count($dbh->query("SHOW COLUMNS FROM `".$settings::db_prefix."positions` LIKE 'aircraft'")->fetchAll()) == 0) {
                        // Add the column if it does not exist.
                        $sql = "ALTER TABLE ".$settings::db_prefix."positions ADD COLUMN aircraft BIGINT";
                        $sth = $dbh->prepare($sql);
                        $sth->execute();
                        $sth = NULL;
                    }
                    $dbh = NULL;
                }

                if ($settings::db_driver == "sqlite") {
                    // Check to see if the column already exists.
                    $dbh = $common->pdoOpen();
                    $columns = $dbh->query("pragma table_info(positions)")->fetchArray(SQLITE3_ASSOC);
                    $columnExists = FALSE;
                    foreach($columns as $column ){
                        if ($column['name'] == 'lastSeen') {
                            $columnExists = TRUE;
                        }
                    }
                    // Add the column if it does not exist.
                    if (!$columnExists) {
                        $sql = "ALTER TABLE ".$settings::db_prefix."positionss ADD COLUMN aircraft BIGINT";
                        $sth = $dbh->prepare($sql);
                        $sth->execute();
                        $sth = NULL;
                    }
                    $dbh = NULL;
                }

            }
            $common->updateSetting("version", "2.1.0");
            $common->updateSetting("patch", "");
        } catch(Exception $e) {
            $error = TRUE;
            $errorMessage = $e->getMessage();
        }
    }

    ///////////////////////
    // UPGRADE TO V2.2.0
    ///////////////////////

    if ($common->getSetting("version") == "2.1.0") {
        try {

            // Add new setting to allow displaying either the dump1090-mutability map and dump1090-fa map.
            $common->addSetting('useDump1090FaMap', FALSE);

            $common->updateSetting("version", "2.2.0");
            $common->updateSetting("patch", "");
        } catch(Exception $e) {
            $error = TRUE;
            $errorMessage = $e->getMessage();
        }
    }

    ///////////////////////
    // UPGRADE TO V2.3.0
    ///////////////////////

    if ($common->getSetting("version") == "2.2.0") {
        try {
            $common->updateSetting("version", "2.3.0");
            $common->updateSetting("patch", "");
        } catch(Exception $e) {
            $error = TRUE;
            $errorMessage = $e->getMessage();
        }
    }

    ///////////////////////
    // UPGRADE TO V2.4.0
    ///////////////////////

    if ($common->getSetting("version") == "2.3.0") {
        try {

           if ($settings::db_driver == "sqlite") {

           // Create a new settings.class.php file adding the path to the SQLite database as the value for the db_host constant.
           $content  = <<<EOF
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
        const db_driver = 'sqlite';
        const db_database = '';
        const db_username = '';
        const db_password = '';
        const db_host = '$_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."portal.sqlite"';
        const db_prefix = 'adsb_';

        // Security Settings
        const sec_length = 6;

        // PDO Settings
        const pdo_debug = TRUE;
    }

?>
EOF;
               file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php", $content);
           }

           // Rename the file flightNotifications.xml to notifications.xml
           rename($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."flightNotifications.xml", $_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."notifications.xml");

           // Add lastSeen as a column to the flightNotifications table.
           if ($settings::db_driver == "mysql") {
                $dbh = $common->pdoOpen();

                // Rename the flightNotifications table to notifications.
                $sql = "RENAME TABLE ".$settings::db_prefix."flightNotifications TO ".$settings::db_prefix."notifications";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;


                // Add the lastMessageCount column to the notifications table..
                $sql = "ALTER TABLE ".$settings::db_prefix."flightNotifications ADD COLUMN lastSeen DATETIME";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $dbh = NULL;
            }

            if ($settings::db_driver == "sqlite") {
                $dbh = $common->pdoOpen();

                // Rename the flightNotifications table to notifications.
                $sql = "ALTER TABLE ".$settings::db_prefix."flightNotifications RENAME TO ".$settings::db_prefix."notifications";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                // Add the column if it does not exist.
                $sql = "ALTER TABLE ".$settings::db_prefix."flightNotifications ADD COLUMN lastSeen DATETIME";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $dbh = NULL;
            }

            // Rename the enableFlightNotifications to enableNotifications.
            $enableNotifications = $common->getSetting('enableFlightNotifications')
            $common->addSetting('enableNotifications', $enableNotifications);
            $common->deleteSetting('enableFlightNotifications');

            // Add new flight notification Twitter settings
            $common->addSetting('enableTwitterNotifications', FALSE);
            $common->addSetting('twitterUserName', '');
            $common->addSetting('twitterConsumerKey', '');
            $common->addSetting('twitterConsumerSecret', '');
            $common->addSetting('twitterAccessToken', '');
            $common->addSetting('twitterAccessTokenSecret', '');

        } catch(Exception $e) {
            $error = TRUE;
            $errorMessage = $e->getMessage();
        }
    }


    require_once('../admin/includes/header.inc.php');

    // Display the instalation wizard.
    if (!$error) {
?>
<h1>ADS-B Receiver Portal Updated</h1>
<p>Your portal has been upgraded to v<?php echo $thisVersion; ?>.</p>
<?php
    } else {
?>
<h1>Error Encountered Upgrading Your ADS-B Receiver Portal</h1>
<p>There was an error encountered when upgrading your portal to v<?php echo $thisVersion; ?>.</p>
<?php echo $errorMessage; ?>
<?php
    }
    require_once('../admin/includes/footer.inc.php');
?>
