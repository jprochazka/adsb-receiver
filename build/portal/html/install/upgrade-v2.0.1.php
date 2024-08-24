<?php
    ///////////////////////
    // UPGRADE TO V2.0.1
    ///////////////////////

    // ------------------------------------------------------------
    // Change columns containing DATETIME values to DATETIME types.
    // Adds the new timezone setting.
    // Updates the version setting to 2.0.1.
    // Removes and current patch version from the patch setting.
    // ------------------------------------------------------------

    $results = upgrade();
    exit(json_encode($results));

    function upgrade() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");

        $common = new common();
        $settings = new settings();

        try {
            // Change tables containing datetime data to datetime.
            if ($settings::db_driver != "mysql") {
                $dbh = $common->pdoOpen();

                $sql = "ALTER TABLE ".$settings::db_prefix."aircraft MODIFY firstSeen DATETIME NOT NULL";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $sql = "ALTER TABLE adsb_aircraft MODIFY lastSeen DATETIME NOT NULL";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $sql = "ALTER TABLE adsb_blogPosts MODIFY date DATETIME NOT NULL";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $sql = "ALTER TABLE adsb_flights MODIFY firstSeen DATETIME NOT NULL";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $sql = "ALTER TABLE adsb_flights MODIFY firstSeen DATETIME NOT NULL";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $sql = "ALTER TABLE adsb_positions MODIFY time DATETIME NOT NULL";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $sth = NULL;

                $dbh = NULL;
            }

            // Add timezone setting.
            $common->addSetting("timeZone", date_default_timezone_get());

            // update the version and patch settings.
            $common->updateSetting("version", "2.0.1");
            $common->updateSetting("patch", "");

            // The upgrade process completed successfully.
            $results['success'] = TRUE;
            $results['message'] = "Upgrade to v2.0.1 successful.";
            return $results;

        } catch(Exception $e) {
            // Something went wrong during this upgrade process.
            $results['success'] = FALSE;
            $results['message'] = $e->getMessage();
            return $results;
        }
    }
?>
