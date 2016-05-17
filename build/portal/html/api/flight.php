<?php

    /////////////////////////////////////////////////////////////////////////////////////
    //                             ADS-B FEEDER PORTAL                                 //
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
        $flightData['afs'] = $aircraft['firstSeen'];
        $flightData['als'] = $aircraft['lastSeen'];
        $flightData['ffs'] = $flight['firstSeen'];
        $flightData['fls'] = $flight['lastSeen'];

        return $flightData;
    }
?>
