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

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");

    $common = new common();

    // The most current stable release.
    $thisVersion = "2.7.1";

    // Begin the upgrade process if this release is newer than what is installed.
    if ($common->getSetting("version") == $thisVersion) {
        header ("Location: /");
    }

    $success = TRUE;

    // UPGRADE TO V2.0.1
    if ($common->getSetting("version") == "2.0.0" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.0.1.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.0.1";
    }

    // UPGRADE TO V2.0.2
    if ($common->getSetting("version") == "2.0.1" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.0.2.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.0.2";
    }

    // UPGRADE RO V2.0.3
    if ($common->getSetting("version") == "2.0.2" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.0.3.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.0.3";
    }

    // UPGRADE TO V2.1.0
    if ($common->getSetting("version") == "2.0.3" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.1.0.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.1.0";
    }

    // UPGRADE TO V2.2.0
    if ($common->getSetting("version") == "2.1.0" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.2.0.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.2.0";
    }

    // UPGRADE TO V2.3.0
    if ($common->getSetting("version") == "2.2.0" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.3.0.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.3.0";
    }

    // UPGRADE TO V2.4.0
    if ($common->getSetting("version") == "2.3.0" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.4.0.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.4.0";
    }

    // UPGRADE TO V2.5.0
    if ($common->getSetting("version") == "2.4.0" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.5.0.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.5.0";
    }

    // UPGRADE TO V2.6.0
    if ($common->getSetting("version") == "2.5.0" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.6.0.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.6.0";
    }

    // UPGRADE TO V2.6.1
    if ($common->getSetting("version") == "2.6.0" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.6.1.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.6.1";
    }

    // UPGRADE TO V2.6.2
    if ($common->getSetting("version") == "2.6.1" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.6.2.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.6.2";
    }

    // UPGRADE TO V2.6.3
    if ($common->getSetting("version") == "2.6.2" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.6.3.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.6.3";
    }

    // UPGRADE TO V2.7.0
    if ($common->getSetting("version") == "2.6.3" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.7.0.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.7.0";
    }

    // UPGRADE TO V2.7.1
    if ($common->getSetting("version") == "2.7.0" && $success) {
        $json = file_get_contents("http://localhost/install/upgrade-v2.7.1.php");
        $results = json_decode($json, TRUE);
        $success = $results['success'];
        $message = $results['message'];
        $version = "2.7.1";
    }

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");

    // Display the instalation wizard.
    if ($success) {
?>
                <h1>ADS-B Receiver Portal Updated</h1>
                <p>Your portal has been upgraded to v<?php echo $version; ?>.</p>
<?php
    } else {
?>
                <h1>Error Encountered Upgrading Your ADS-B Receiver Portal</h1>
                <p>There was an error encountered when upgrading your portal to v<?php echo $version; ?>.</p>
                <?php echo $message; ?>
<?php
    }
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>
