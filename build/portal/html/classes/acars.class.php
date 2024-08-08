<?php
    class acars {

        function getAcarsMessages($limit = 100, $offset = 0) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
            $common = new common();

            $dsn = "sqlite:".$common->getSetting('acarsserv_database');
            $dbh = new PDO($dsn, null, null, [PDO::SQLITE_ATTR_OPEN_FLAGS => PDO::SQLITE_OPEN_READONLY]);
            $sql = "SELECT * FROM Messages JOIN Flights USING(FlightID) JOIN Stations USING(StID) ORDER BY LastTime DESC LIMIT :limit OFFSET :offset";
            $sth = $dbh->prepare($sql);
            $sth->bindValue(':limit', $limit);
            $sth->bindValue(':offset', $offset);
            $sth->execute();
            $acarsMessages = $sth->fetchAll(PDO::FETCH_ASSOC);
            $sth = NULL;
            $dbh = NULL;
            $dsn = NULL;

            return $acarsMessages;
        }
    }
?>
