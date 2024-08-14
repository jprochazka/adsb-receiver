<?php
    $possibleActions = array("flights");

    if (isset($_GET['type']) && in_array($_GET["type"], $possibleActions)) {
        switch ($_GET["type"]) {
            case "flights":
                $queryArray = getVisibleFlights();
                break;
        }
        exit(json_encode($queryArray));
    } else {
        http_response_code(404);
    }

    function getVisibleFlights() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");

        $settings = new settings();
        $common = new common();

        // Get all flights to be notified about from the flightNotifications.xml file.
        $lookingFor = array();

        if ($settings::db_driver == "xml") {
            // XML
            $savedFlights = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."flightNotifications.xml");
            foreach ($savedFlights as $savedFlight) {
                $lookingFor[] = array($savedFlight);
            }
        } else {
            // PDO
            $dbh = $common->pdoOpen();
            $sql = "SELECT flight FROM ".$settings::db_prefix."flightNotifications";
            $sth = $dbh->prepare($sql);
            $sth->execute();
            $lookingFor = $sth->fetchAll();
            $sth = NULL;
            $dbh = NULL;
        }

        // Check dump1090-mutability's aircraft JSON output to see if the flight is visible.
        $visibleFlights = array();
        $url = "http://localhost/dump1090/data/aircraft.json";
        $json = file_get_contents($url);
        $data = json_decode($json, true);
        foreach ($data['aircraft'] as $aircraft) {
            if (array_key_exists('flight', $aircraft)) {
                $visibleFlights[] = strtoupper(trim($aircraft['flight']));
            }
        }

        $foundFlights = array();
        foreach ($lookingFor as $flight) {
            if(strpos($flight[0], "%") !== false) {
                $searchFor = str_replace("%", "", $flight[0]);
                foreach ($visibleFlights as $visible) {
                    if (strpos(strtolower($visible), strtolower($searchFor)) !== false) {
                        $foundFlights[] = $visible;
                    }
                }
            } else {
                if (in_array($flight[0], $visibleFlights)) {
                    $foundFlights[] = $flight[0];
                }
            }
        }


        return json_decode(json_encode((array)$foundFlights), true);
    }
?>
