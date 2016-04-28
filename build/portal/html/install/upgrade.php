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
    $thisVersion = "2.0.1";

    // Begin the upgrade process if this release is newer than what is installed.
    if ($common->getSetting("version") == $thisVersion) {
        header ("Location: /");
    }

    $error = FALSE;
    #errorMessage = "No error message returned.";

    try {
        // Change tables containing datetime data to datetime.
        if ($settings::db_driver != "xml") {
            $dbh = $common->pdoOpen();

            $sql = "ALTER TABLE adsb_aircraft MODIFY firstSeen DATETIME NOT NULL";
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

        // update version and patch settings.
        $common->updateSetting("version", $thisVersion);
        $common->updateSetting("patch", "");
    } catch(Exception $e) {
        $error = TRUE;
        $errorMessage = $e->getMessage();
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
