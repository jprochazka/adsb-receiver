<?php
    ///////////////////////
    // UPGRADE TO V2.7.2
    ///////////////////////

    // --------------------------------------------------------
    // Updates the version setting to 2.7.2.
    // Add indexes to the aircraft and positions tables.
    // --------------------------------------------------------

    $results = upgrade();
    exit(json_encode($results));

    function upgrade() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");

        $common = new common();
        $settings = new settings();

        try {

            if ($settings::db_driver == "mysql" || $settings::db_driver == "sqlite") {

                // Add an index to the aircraft table.
                $dbh = $common->pdoOpen();
                $sql = "CREATE INDEX IF NOT EXISTS idxIcao ON ".$settings::db_prefix."aircraft(icao)";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;

                // Add an index to the positions table.
                $dbh = $common->pdoOpen();
                $sql = "CREATE INDEX IF NOT EXISTS idxFlight ON ".$settings::db_prefix."positions(flight)";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }

            // Update the version and patch settings..
            $common->updateSetting("version", "2.7.2");
            $common->updateSetting("patch", "");

            // The upgrade process completed successfully.
            $results['success'] = TRUE;
            $results['message'] = "Upgrade to v2.7.2 successful.";
            return $results;

        } catch(Exception $e) {
            // Something went wrong during this upgrade process.
            $results['success'] = FALSE;
            $results['message'] = $e->getMessage();
            return $results;
        }
    }
?>

