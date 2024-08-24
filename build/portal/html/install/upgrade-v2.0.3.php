<?php
    ///////////////////////
    // UPGRADE TO V2.0.3
    ///////////////////////

    // ---------------------------------------------------------
    // Updates the version setting to 2.0.3.
    // Removes and current patch version from the patch setting.
    // ---------------------------------------------------------

    $results = upgrade();
    exit(json_encode($results));

    function upgrade() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");

        $common = new common();

        try {
            // Update the version and patch settings..
            $common->updateSetting("version", "2.0.3");
            $common->updateSetting("patch", "");

            // The upgrade process completed successfully.
            $results['success'] = TRUE;
            $results['message'] = "Upgrade to v2.0.3 successful.";
            return $results;

        } catch(Exception $e) {
            // Something went wrong during this upgrade process.
            $results['success'] = FALSE;
            $results['message'] = $e->getMessage();
            return $results;
        }
    }
?>

