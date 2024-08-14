<?php
    ///////////////////////
    // UPGRADE TO V2.7.0
    ///////////////////////

    // ------------------------------------------------------------------------------------------
    // Updates the version setting to 2.7.0.
    // Added options to set the default latitude and longitude for the advanced features map.
    // ------------------------------------------------------------------------------------------

    $results = upgrade();
    exit(json_encode($results));

    function upgrade() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");

        $common = new common();
        $settings = new settings();

        try {
            // Add map centering longitude and latitude.
            $common->addSetting("advancedMapCenterLatitude", "41.3683798");
            $common->addSetting("advancedMapCenterLongitude", "-82.1076486");

            // Update the version and patch settings..
            $common->updateSetting("version", "2.7.0");
            $common->updateSetting("patch", "");

            // The upgrade process completed successfully.
            $results['success'] = TRUE;
            $results['message'] = "Upgrade to v2.7.0 successful.";
            return $results;

        } catch(Exception $e) {
            // Something went wrong during this upgrade process.
            $results['success'] = FALSE;
            $results['message'] = $e->getMessage();
            return $results;
        }
    }
?>

