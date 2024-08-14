<?php
    ///////////////////////
    // UPGRADE TO V2.2.0
    ///////////////////////

    // ---------------------------------------------------------
    // Adds the new useDump1090FaMap map setting.
    // Updates the version setting to 2.2.0.
    // Removes and current patch version from the patch setting.
    // ---------------------------------------------------------

    $results = upgrade();
    exit(json_encode($results));

    function upgrade() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");

        $common = new common();

        try {
            // Add new setting to allow displaying either the dump1090-mutability map and dump1090-fa map.
            $common->addSetting('useDump1090FaMap', FALSE);

            // Update the version and patch settings..
            $common->updateSetting("version", "2.2.0");
            $common->updateSetting("patch", "");

            // The upgrade process completed successfully.
            $results['success'] = TRUE;
            $results['message'] = "Upgrade to v2.2.0 successful.";
            return $results;

        } catch(Exception $e) {
            // Something went wrong during this upgrade process.
            $results['success'] = FALSE;
            $results['message'] = $e->getMessage();
            return $results;
        }
    }
?>
