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

    ///////////////////////
    // UPGRADE TO V2.5.0
    ///////////////////////

    // ------------------------------------------------------------------------------------------
    // If using SQLite creates a new settings.class.php file containing the path to the database.
    // Renames flightNotifications.xml to notifications.xml.
    // Renames the flightNotifications table to notifications on MySQL and SQLite databases.
    // Adds the lastMessageCount column to the notifications table on MySQL and SQLite databases.
    // Renames the enableFlightNotifications setting to enableNotifications.
    // Adds new Twitter API settings.
    // Updates the version setting to 2.4.0.
    // Removes and current patch version from the patch setting.
    // ------------------------------------------------------------------------------------------

    $results = upgrade();
    exit(json_encode($results));

    function upgrade() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");

        $common = new common();
        $settings = new settings();

        try {
            if ($settings::db_driver == "xml") {
                // Rename the file flightNotifications.xml to notifications.xml
                rename($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."flightNotifications.xml", $_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."notifications.xml");

                // Create XML files used to store links data.
                $xml = new XMLWriter();
                $xml->openMemory();
                $xml->setIndent(true);
                $xml->startDocument('1.0','UTF-8');
                $xml->startElement("links");
                $xml->endElement();
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml", $xml->flush(true));
            }

            if ($settings::db_driver == "mysql") {
                $dbh = $common->pdoOpen();

                // Rename the flightNotifications table to notifications.
                $sql = "RENAME TABLE ".$settings::db_prefix."flightNotifications TO ".$settings::db_prefix."notifications";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                // Add the lastMessageCount column to the flightNotifications table.
                $sql = "ALTER TABLE ".$settings::db_prefix."notifications ADD COLUMN lastMessageCount INT";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                // Add the links table.
                $sql = "CREATE TABLE ".$settings::db_prefix."links(id INT(11) AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL, address VARCHAR(250) NOT NULL);";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $dbh = NULL;
            }

            if ($settings::db_driver == "sqlite") {
                // Create a new settings.class.php file adding the path to the SQLite database as the value for the db_host constant.
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
        const db_driver = 'sqlite';
        const db_database = '';
        const db_username = '';
        const db_password = '';
        const db_host = '/var/www/html/portal.sqlite';
        const db_prefix = 'adsb_';

        // Security Settings
        const sec_length = 6;

        // PDO Settings
        const pdo_debug = TRUE;
    }

?>
EOF;
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php", $content);

                // Open a connection to the database.
                $dbh = $common->pdoOpen();

                // Rename the flightNotifications table to notifications.

                $sql = "ALTER TABLE ".$settings::db_prefix."flightNotifications RENAME TO ".$settings::db_prefix."notifications";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                // Add the lastMessageCount column to the notifications table.
                $sql = "ALTER TABLE ".$settings::db_prefix."notifications ADD COLUMN lastMessageCount DATETIME";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                // Add the links table.
                $sql = "CREATE TABLE ".$dbPrefix."links(id INT(11) AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL, address VARCHAR(250) NOT NULL);";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $dbh = NULL;
            }

            // Rename the enableFlightNotifications to enableWebNotifications.
            $enableWebNotifications = $common->getSetting('enableFlightNotifications');
            $common->addSetting('enableWebNotifications', $enableWebNotifications);
            $common->deleteSetting('enableFlightNotifications');

            // Add new flight notification settings.
            $common->addSetting('enableEmailNotifications', FALSE);
            $common->addSetting('enableTwitterNotifications', FALSE);
            $common->addSetting('emailNotificationAddresses', '');

            // Add Twitter API settings.
            $common->addSetting('twitterUserName', '');
            $common->addSetting('twitterConsumerKey', '');
            $common->addSetting('twitterConsumerSecret', '');
            $common->addSetting('twitterAccessToken', '');
            $common->addSetting('twitterAccessTokenSecret', '');

            // Add Google Maps API Key setting.
            $common->addSetting('googleMapsApiKey', '');

            // Add enable custom links setting.
            $common->addSetting('enableLinks', FALSE);

            // Update the version and patch settings..
            $common->updateSetting("version", "2.5.0");
            $common->updateSetting("patch", "");

            // The upgrade process completed successfully.
            $results['success'] = TRUE;
            $results['message'] = "Upgrade to v2.5.0 successful.";
            return $results;

        } catch(Exception $e) {
            // Something went wrong during this upgrade process.
            $results['success'] = FALSE;
            $results['message'] = $e->getMessage();
            return $results;
        }
    }
?>

