<?php
    $possibleActions = array("byPosition");

    if (isset($_GET['type']) && in_array($_GET["type"], $possibleActions)) {
        switch ($_GET["type"]) {
            case "byPosition":
                $informationArray = getByPosition();
                break;
        }
        exit(json_encode($informationArray));
    } else {
        http_response_code(404);
    }

    function getByPosition() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");

        $settings = new settings();
        $common = new common();

        //
        $flightData = array();

        // PDO
        $dbh = $common->pdoOpen();
        $sql = "SELECT flight, aircraft FROM ".$settings::db_prefix."positions WHERE id = :id";
        $sth = $dbh->prepare($sql);
        $sth->bindParam(':id', $_GET['position'], PDO::PARAM_INT);
        $sth->execute();
        $position = $sth->fetch();
        $sth = NULL;
        $dbh = NULL;

        $dbh = $common->pdoOpen();
        $sql = "SELECT flight, firstSeen, lastSeen FROM ".$settings::db_prefix."flights WHERE id = :id";
        $sth = $dbh->prepare($sql);
        $sth->bindParam(':id', $position['flight'], PDO::PARAM_INT);
        $sth->execute();
        $flight = $sth->fetch();
        $sth = NULL;
        $dbh = NULL;

        $dbh = $common->pdoOpen();
        $sql = "SELECT icao, firstSeen, lastSeen FROM ".$settings::db_prefix."aircraft WHERE id = :id";
        $sth = $dbh->prepare($sql);
        $sth->bindParam(':id', $position['flight'], PDO::PARAM_INT);
        $sth->execute();
        $aircraft = $sth->fetch();
        $sth = NULL;
        $dbh = NULL;

        $flightData['icao'] = $aircraft['icao'];
        $flightData['flight'] = $flight['flight'];

        $date = new DateTime($aircraft['firstSeen'], new DateTimeZone('UTC'));
        $date->setTimezone(new DateTimeZone($common->getSetting('timeZone')));
        $flightData['afs'] = $date->format($common->getSetting('dateFormat'));

        $date = new DateTime($aircraft['lastSeen'], new DateTimeZone('UTC'));
        $date->setTimezone(new DateTimeZone($common->getSetting('timeZone')));
        $flightData['als'] = $date->format($common->getSetting('dateFormat'));

        $date = new DateTime($flight['firstSeen'], new DateTimeZone('UTC'));
        $date->setTimezone(new DateTimeZone($common->getSetting('timeZone')));
        $flightData['ffs'] = $date->format($common->getSetting('dateFormat'));

        $date = new DateTime($flight['lastSeen'], new DateTimeZone('UTC'));
        $date->setTimezone(new DateTimeZone($common->getSetting('timeZone')));
        $flightData['fls'] = $date->format($common->getSetting('dateFormat'));

        return $flightData;
    }
?>
