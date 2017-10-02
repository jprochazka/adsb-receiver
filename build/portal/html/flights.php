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

    // Items per page.
    $itemsPerPage = 25;

    // The title of this page.
    $pageData['title'] = "Flights Seen";

    // Add flight data to the $pageData array using the search string if available.
    if (isset($_POST['flight'])) {
        $searchString = $_POST['flight'];
    } else {
        $searchString = "";
    }

    // Set the start stop positions to be used in the query.
    $start = 1;
    if (isset($_GET['page'])) {
        $start = $_GET['page'] * $itemsPerPage;
    }

    $dbh = $common->pdoOpen();
    $sql = "SELECT COUNT(*) FROM ".$settings::db_prefix."flights WHERE flight LIKE :like ORDER BY lastSeen DESC, flight";
    $sth = $dbh->prepare($sql);
    $sth->bindValue(':like', "%".$searchString."%", PDO::PARAM_STR);
    $sth->execute();
    $totalFlights = $sth->fetchColumn();
    $sth = NULL;
    $dbh = NULL;

    $dbh = $common->pdoOpen();
    $sql = "SELECT * FROM ".$settings::db_prefix."flights WHERE flight LIKE :like ORDER BY lastSeen DESC, flight LIMIT :start, :items";
    $sth = $dbh->prepare($sql);
    $sth->bindValue(':like', "%".$searchString."%", PDO::PARAM_STR);
    $sth->bindValue(':start', $start, PDO::PARAM_INT);
    $sth->bindValue(':items', $itemsPerPage, PDO::PARAM_INT);
    $sth->execute();
    $flights = $sth->fetchAll(PDO::FETCH_ASSOC);
    $sth = NULL;
    $dbh = NULL;

    // Change dates to the proper timezone and format.
    foreach ($flights as &$flight) {
        $date = new DateTime($flight['firstSeen'], new DateTimeZone('UTC'));
        $date->setTimezone(new DateTimeZone($common->getSetting('timeZone')));
        $flight['firstSeen'] = $date->format($common->getSetting('dateFormat'));

        $date = new DateTime($flight['lastSeen'], new DateTimeZone('UTC'));
        $date->setTimezone(new DateTimeZone($common->getSetting('timeZone')));
        $flight['lastSeen'] = $date->format($common->getSetting('dateFormat'));
    }

    $pageData['flights'] = $flights;

    // Calculate the number of pagination links to show.
    $pageData['pageLinks'] = ceil($totalFlights / $itemsPerPage - 1);

    // Pass the current page number being viewed to the template.
    $pageData['pageNumber'] = 1;
    if (isset($_GET['page'])) {
        $pageData['pageNumber'] = $_GET['page'];
    }

    $template->display($pageData);
?>
