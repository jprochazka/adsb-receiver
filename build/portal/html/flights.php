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
    $start = 0;
    if (isset($_GET['page'])) {
        $start = $_GET['page'] * $itemsPerPage;
    }

    $dbh = $common->pdoOpen();
    $sql = "SELECT COUNT(*) FROM ".$settings::db_prefix."flights WHERE flight LIKE :like AND EXISTS (SELECT * FROM ".$settings::db_prefix."positions WHERE ".$settings::db_prefix."positions.flight = ".$settings::db_prefix."flights.id)";
    $sth = $dbh->prepare($sql);
    $sth->bindValue(':like', "%".$searchString."%", PDO::PARAM_STR);
    $sth->execute();
    $totalFlights = $sth->fetchColumn();
    $sth = NULL;
    $dbh = NULL;

    $dbh = $common->pdoOpen();
    $sql = "SELECT * FROM ".$settings::db_prefix."flights WHERE flight LIKE :like AND EXISTS (SELECT * FROM ".$settings::db_prefix."positions WHERE ".$settings::db_prefix."positions.flight = ".$settings::db_prefix."flights.id) ORDER BY lastSeen DESC, flight LIMIT :start, :items";
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
