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
    $thisVersion = "2.2.0";

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

            // Add the positions.aircraft column if using "SQL" storeage.
            if ($settings::db_driver != "xml") {

                if ($settings::db_driver == "sqlite") {
                    // In SQLite aircraft.flight should have been an INTEGER not TEXT column.
                    // Since SQLite does not fully support ALTER TABLE allowing the change to be done easily this change will be skipped.
                    // This change will be addressed in the future if a problem arises with this column not being specifed as an INTEGER.

                    // Add FAA database tables.
                    // The FAA database will not be used.
                    // These tables will be remove in the future once it is known it will not effect the portal once removed.
                    $faaMasterSql = 'CREATE TABLE '.$dbPrefix.'faa_master (
                                       nNumber VARCHAR(5) NOT NULL,
                                       serialNumber VARCHAR(30) NULL,
                                       mfrMdlCode VARCHAR(7) NULL,
                                       engMfrMdl VARCHAR(5) NULL,
                                       yearMfr VARCHAR(4) NULL,
                                       typeRegistrant VARCHAR(50) NULL,
                                       name VARCHAR(33) NULL,
                                       street VARCHAR(33) NULL,
                                       street2 VARCHAR(18) NULL,
                                       city VARCHAR(2) NULL,
                                       state VARCHAR(10) NULL,
                                       zipCode VARCHAR(1) NULL,
                                       region VARCHAR(3) NULL,
                                       county VARCHAR(2) NULL,
                                       country VARCHAR(8) NULL,
                                       lastActionDate VARCHAR(8) NULL,
                                       certIssueDate VARCHAR(10) NULL,
                                       certification VARCHAR(1) NULL,
                                       typeAircraft VARCHAR(2) NULL,
                                       typeEngine VARCHAR(2) NULL,
                                       statusCode VARCHAR(8) NULL,
                                       modeSCode VARCHAR(1) NULL,
                                       fractOwner VARCHAR(8) NULL,
                                       airWorthDate VARCHAR(50) NULL,
                                       otherNames1 VARCHAR(50) NULL,
                                       otherNames2 VARCHAR(50) NULL,
                                       otherNames3 VARCHAR(50) NULL,
                                       otherNames4 VARCHAR(50) NULL,
                                       otherNames5 VARCHAR(50) NULL,
                                       experiationDate VARCHAR(8) NULL,
                                       uniqueId VARCHAR(8) NULL,
                                       kitMfr VARCHAR(30) NULL,
                                       kitModel VARCHAR(20) NULL,
                                       modeSCodeHex VARCHAR(10) NULL);';

                    $faaAcftrefSql = 'CREATE TABLE '.$dbPrefix.'faa_acftref (
                                        code VARCHAR(7) NOT NULL,
                                        mfr VARCHAR(30) NULL,
                                        model VARCHAR(20) NULL,
                                        typeAcft VARCHAR(1) NULL,
                                        typeEng VARCHAR(2) NULL,
                                        acCat VARCHAR(1) NULL,
                                        buildCertInd VARCHAR(1) NULL,
                                        noEng VARCHAR(2) NULL,
                                        noSeats VARCHAR(3) NULL,
                                        acWeight VARCHAR(7) NULL,
                                        speed VARCHAR(4) NULL);';

                    $faaEngineSql = 'CREATE TABLE '.$dbPrefix.'faa_engine (
                                       code VARCHAR(7) NOT NULL,
                                       mfr VARCHAR(30) NULL,
                                       model VARCHAR(20) NULL,
                                       typeAcft VARCHAR(1) NULL,
                                       typeEng VARCHAR(2) NULL,
                                       acCat VARCHAR(1) NULL,
                                       buildCertInd VARCHAR(1) NULL,
                                       noEng VARCHAR(2) NULL,
                                       noSeats VARCHAR(3) NULL,
                                       acWeight VARCHAR(7) NULL,
                                       speed VARCHAR(4) NULL);';

                    $sth = $dbh->prepare($faaMasterSql);
                    $sth->execute();
                    $sth = NULL;

                    $dbh = NULL;
                }

                if ($settings::db_driver == "mysql") {
                    // Added check to see if column already exists.
                    $dbh = $common->pdoOpen();
                    if (count($dbh->query("SHOW COLUMNS FROM `".$settings::db_prefix."positions` LIKE 'aircraft'")->fetchAll())) {
                        //$dbh = $common->pdoOpen();
                        $sql = "ALTER TABLE ".$settings::db_prefix."positions ADD COLUMN aircraft BIGINT";
                        $sth = $dbh->prepare($sql);
                        $sth->execute();
                        $sth = NULL;
                        //$dbh = NULL;
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
