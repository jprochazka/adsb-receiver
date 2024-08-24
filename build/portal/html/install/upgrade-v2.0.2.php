<?php
    ///////////////////////
    // UPGRADE TO V2.0.2
    ///////////////////////

    // ---------------------------------------------------------
    // Set the proper permissions on the SQLite database file.
    // Updates the version setting to 2.0.2.
    // Removes and current patch version from the patch setting.
    // ---------------------------------------------------------

    $results = upgrade();
    exit(json_encode($results));

    function upgrade() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");

        $common = new common();
        $settings = new settings();

        try {
            // Set proper permissions on the SQLite file.
            if ($settings::db_driver == "sqlite") {
                chmod($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."portal.sqlite", 0666);
            }

            // Update the version and patch settings..
            $common->updateSetting("version", "2.0.2");
            $common->updateSetting("patch", "");

            // The upgrade process completed successfully.
            $results['success'] = TRUE;
            $results['message'] = "Upgrade to v2.0.2 successful.";
            return $results;

        } catch(Exception $e) {
            // Something went wrong during this upgrade process.
            $results['success'] = FALSE;
            $results['message'] = $e->getMessage();
            return $results;
        }
    }
?>
