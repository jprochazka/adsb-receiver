<?php
    class acars {

        function getAcarsMessages($limit = 100, $offset = 0) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
            $common = new common();

            $dsn = "sqlite:".$settings::acarsserv_database;
            $dbh = new PDO($dsn);
            $sql = "
                SELECT * FROM Messages
                JOIN Flights USING(FlightID)
                JOIN Stations USING(StID)
                ORDER BY LastTime DESC LIMIT 100 OFFSET 0
            ";
            $sth = $dbh->prepare($sql);
            $sth->bindValue(':limit', $limit);
            $sth->bindValue(':offset', $offset);
            $sth->execute();
            $acarsMessages = $sth->fetchAll(PDO::FETCH_ASSOC);
            $sth = NULL;
            $dbh = NULL;

            return $acarsMessages;
        }
    }
?>