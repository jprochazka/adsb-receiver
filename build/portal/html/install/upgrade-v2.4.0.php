<?php
    ///////////////////////
    // UPGRADE TO V2.3.0
    ///////////////////////

    // ---------------------------------------------------------------
    // Removes the useDump1090FaMap setting which is no longer needed.
    // Updates the version setting to 2.3.0.
    // Removes and current patch version from the patch setting.
    // ---------------------------------------------------------------

    $results = upgrade();
    exit(json_encode($results));

    function upgrade() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");

        $common = new common();

        try {
            // Remove the dump1090-fa map selection setting.
            $common->deleteSetting('useDump1090FaMap');

            // Update the version and patch settings..
            $common->updateSetting("version", "2.4.0");
            $common->updateSetting("patch", "");

            // The upgrade process completed successfully.
            $results['success'] = TRUE;
            $results['message'] = "Upgrade to v2.4.0 successful.";
            return $results;

        } catch(Exception $e) {
            // Something went wrong during this upgrade process.
            $results['success'] = FALSE;
            $results['message'] = $e->getMessage();
            return $results;
        }
    }
?>
