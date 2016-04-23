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
    $settings = new setting();

    // Convert local times stored in the database to UNIX timestamps time.
    if ($settings::db_driver != "xml") {

        $dbh = $this->pdoOpen();
        $sql = "SELECT id, firstSeen, lastSeen FROM ".$settings::db_prefix."positions";
        $sth = $dbh->prepare($sql);
        $sth->execute();
        $flights = $sth->fetchAll();
        $sth = NULL;
        $dbh = NULL;

        foreach ($flights as $flight) {
            $utcFirstSeen = gmdate("M d Y H:i:s", strtotime($flight['firstSeen']));
            $utcLastSeen = gmdate("M d Y H:i:s", strtotime($flight['lastSeen']));

            $dbh = $this->pdoOpen();
            $sql = "UPDATE ".$settings::db_prefix."positions SET firstSeen = :firstSeen, lastSeen = :lastSeen WHERE id = :id";
            $sth = $dbh->prepare($sql);
            $sth->bindParam(':firstSeen', $utcFirstSeen, PDO::PARAM_STR);
            $sth->bindParam(':lastSeen', $utcLastSeen, PDO::PARAM_STR);
            $sth->bindParam(':id', $flight['id'], PDO::PARAM_INT);
            $sth->execute();
            $sth = NULL;
            $dbh = NULL;

        }

        $dbh = $this->pdoOpen();
        $sql = "SELECT id, time FROM ".$settings::db_prefix."positions";
        $sth = $dbh->prepare($sql);
        $sth->execute();
        $positions = $sth->fetchAll();
        $sth = NULL;
        $dbh = NULL;

        foreach ($positions as $position) {
            $utcTime = gmdate("M d Y H:i:s", strtotime($flight['time']));

            $dbh = $this->pdoOpen();
            $sql = "UPDATE ".$settings::db_prefix."positions SET time = :time WHERE id = :id";
            $sth = $dbh->prepare($sql);
            $sth->bindParam(':time', $utcTime, PDO::PARAM_STR);
            $sth->bindParam(':id', $flight['id'], PDO::PARAM_INT);
            $sth->execute();
            $sth = NULL;
            $dbh = NULL;
        }

    }
?>
