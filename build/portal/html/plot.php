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

    // Start session
    session_start();

    // Load the common PHP classes.
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."template.class.php");

    $common = new common();
    $settings = new settings();
    $template = new template();

    $pageData = array();

    // The title of this page.
    $pageData['title'] = "Flight Plot for Flight ".$_GET['flight'];

    // Add position data to the $pageData array.
    $dbh = $common->pdoOpen();
    $sql = "SELECT id FROM ".$settings::db_prefix."flights WHERE flight = :flight";
    $sth = $dbh->prepare($sql);
    $sth->bindParam(':flight', $_GET['flight'], PDO::PARAM_STR, 50);
    $sth->execute();
    $row = $sth->fetch();
    $sth = NULL;
    $dbh = NULL;
    $flightId = $row['id'];

    $dbh = $common->pdoOpen();
    $sql = "SELECT time, message, latitude, longitude, track FROM ".$settings::db_prefix."positions WHERE flight = :flight ORDER BY time";
    $sth = $dbh->prepare($sql);
    $sth->bindParam(':flight', $flightId, PDO::PARAM_STR, 50);
    $sth->execute();
    $positions = $sth->fetchAll();
    $sth = NULL;
    $dbh = NULL;

    $thisPath = array();
    $flightPath = array();
    $flightPaths = array();
    $lastMessage = 0;
    $firstPass = TRUE;
    $firstPosition = TRUE;
    foreach ($positions as $position) {
        if ($firstPass == TRUE && $firstPosition == TRUE) {
            $startingLatitude = $position["latitude"];
            $startingLongitude = $position["longitude"];
            $firstPosition == FALSE;
        }

        if ($position["message"] < $lastMessage) {
            if ($firstPass == TRUE) {
                $flightPath["startingLatitude"] = $startingLatitude;
                $flightPath["startingLongitude"] = $startingLongitude;
            } else {
                $flightPath["startingLatitude"] = $position["latitude"];
                $flightPath["startingLongitude"] = $position["longitude"];
            }
            $flightPath["startingTrack"] = $position["track"];
            $flightPath["finishingLatitude"] = $lastLatitude;
            $flightPath["finishingLongitude"] = $lastLongitude;
            $flightPath["finishingTrack"] = $lastTrack;
            $flightPath["positions"] = json_encode($thisPath);
            $flightPaths[] = $flightPath;
            unset($thisPath);
            unset($flightPath);
            $firstPass = FALSE;
        }

        $thisPosition["time"] = $position["time"];
        $thisPosition["latitude"] = $position["latitude"];
        $thisPosition["longitude"] = $position["longitude"];
        $thisPosition["track"] = $position["track"];
        $thisPosition["message"] = $position["message"];

        $thisPath[] = $thisPosition;

        $lastMessage = $position["message"];
        $lastLatitude = $position["latitude"];
        $lastLongitude = $position["longitude"];
        $lastTrack = $position["track"];
    }

    if (count($flightPaths) > 0) {
        $pageData['flightPathsAvailable'] = "TRUE";
        $pageData['flightPaths'] = $flightPaths;
    } else {
        $pageData['flightPathsAvailable'] = "FALSE";
    }

    $template->display($pageData);
?>

