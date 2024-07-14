<?php
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
    $sql = "SELECT id, aircraft, flight, firstSeen, lastSeen FROM ".$settings::db_prefix."flights WHERE flight = :flight";
    $sth = $dbh->prepare($sql);
    $sth->bindParam(':flight', $_GET['flight'], PDO::PARAM_STR, 50);
    $sth->execute();
    $row = $sth->fetch();
    $sth = NULL;
    $dbh = NULL;
    $flightId = $row['id'];
    $aircraftId = $row['aircraft'];
    $pageData['flight'] = $row['flight'];
    $pageData['flightFirstSeen'] = $row['firstSeen'];
    $pageData['flightLastSeen'] = $row['lastSeen'];

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

    // Page Data
    $dbh = $common->pdoOpen();
    $sql = "SELECT icao, firstSeen, lastSeen FROM ".$settings::db_prefix."aircraft WHERE id = :id";
    $sth = $dbh->prepare($sql);
    $sth->bindParam(':id', $aircraftId, PDO::PARAM_STR, 50);
    $sth->execute();
    $row = $sth->fetch();
    $sth = NULL;
    $dbh = NULL;
    $pageData['icao'] = $row['icao'];
    $pageData['aircraftFirstSeen'] = $row['firstSeen'];
    $pageData['aircraftLastSeen'] = $row['lastSeen'];

    // Planespotter.net image.
    $url = 'https://api.planespotters.net/pub/photos/hex/'.$pageData['icao'];
    $json = file_get_contents($url);
    $planspotterData = json_decode($json);
    $pageData['thumbnailSrc'] = $planspotterData->photos[0]->thumbnail->src;
    $pageData['thumbnailWidth'] = $planspotterData->photos[0]->thumbnail->size->width;
    $pageData['thumbnailHeight'] = $planspotterData->photos[0]->thumbnail->size->height;
    $pageData['thumbnailPhotographer'] = $planspotterData->photos[0]->photographer;
    $pageData['thumbnailLink'] = $planspotterData->photos[0]->link;

    $template->display($pageData);
?>
