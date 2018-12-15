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
    $sql = "SELECT * FROM ".$settings::db_prefix."positions WHERE flight = :flight ORDER BY time";
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
    $totalPositions = count($positions);
    $counter = 0;
    $id = 1;
    $pathsSeen = 0;
    foreach ($positions as $position) {
        $counter++;

        if ($position["message"] < $lastMessage || $counter == $totalPositions) {
            $flightPath["finishingId"] = $lastId;
            $flightPath["finishingTime"] = $lastTime;
            $flightPath["finishingSquawk"] = $lastSquawk;
            $flightPath["finishingLatitude"] = $lastLatitude;
            $flightPath["finishingLongitude"] = $lastLongitude;
            $flightPath["finishingTrack"] = $lastTrack;
            $flightPath["finishingAltitude"] = $lastAltitude;
            $flightPath["finishingVerticleRate"] = $lastVerticleRate;
            $flightPath["finishingSpeed"] = $lastSpeed;
            $flightPath["positions"] = json_encode($thisPath);
            $flightPaths[] = $flightPath;

            unset($thisPath);
            unset($flightPath);
            $thisPath = array();
            $flightPath = array();

            $pathsSeen++;
            $firstPosition = TRUE;
        }

        if ($firstPosition == TRUE) {
            $flightPath["id"] = $id++;
            $flightPath["startingId"] = $position["id"];
            $flightPath["startingTime"] = $position["time"];
            $flightPath["startingSquawk"] = $position["squawk"];
            $flightPath["startingLatitude"] = $position["latitude"];
            $flightPath["startingLongitude"] = $position["longitude"];
            $flightPath["startingTrack"] = $position["track"];
            $flightPath["startingAltitude"] = $position["altitude"];
            $flightPath["startingVerticleRate"] = $position["verticleRate"];
            $flightPath["startingSpeed"] = $position["speed"];
            $firstPosition = FALSE;
        }

        $thisPosition["id"] = $position["id"];
        $thisPosition["time"] = $position["time"];
        $thisPosition["latitude"] = $position["latitude"];
        $thisPosition["longitude"] = $position["longitude"];
        $thisPosition["track"] = $position["track"];
        $thisPosition["message"] = $position["message"];
        $thisPath[] = $thisPosition;

        $lastId = $position["id"];
        $lastMessage = $position["message"];
        $lastTime = $position["time"];
        $lastSquawk = $position["squawk"];
        $lastLatitude = $position["latitude"];
        $lastLongitude = $position["longitude"];
        $lastTrack = $position["track"];
        $lastAltitude = $position["altitude"];
        $lastVerticleRate = $position["verticleRate"];
        $lastSpeed = $position["speed"];
    }

    // Pass the number of seen paths which is equal to the last flight ID.
    $pageData['pathsSeen'] = $pathsSeen;

    $countFlightPaths = count($flightPaths);
    if ($countFlightPaths > 0) {
        $pageData['flightPathsAvailable'] = "TRUE";
        $selectedFlightPath = $flightPaths;

        if (isset($_GET["index"])) {
            switch ($_GET["index"]) {
                case "first":
                    $selectedFlightPath = [$flightPaths[0]];
                    break;
                case "last":
                    $selectedFlightPath = [$flightPaths[$countFlightPaths - 1]];
                    break;
                default:
                    if (is_numeric($_GET["index"])) {
                        $selectedFlightPath = [$flightPaths[$_GET["index"]]];
                    }
                    break;
            }
        } 
        
        $pageData['flightPaths'] = $selectedFlightPath;

    } else {
        $pageData['flightPathsAvailable'] = "FALSE";
    }

    $template->display($pageData);
?>
