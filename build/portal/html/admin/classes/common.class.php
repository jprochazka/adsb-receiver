<?php
     class common {

        ////////////////////////////////////////
        // Check if page load is a post back.

        function postBack() {
            if (empty($_SERVER['HTTP_REFERER'])) {
                return FALSE;
            }
            $methodUsed = strtoupper($_SERVER['REQUEST_METHOD']);
            $referer = strtolower(basename($_SERVER['HTTP_REFERER']));
            $thisScript = strtolower(basename($_SERVER['SCRIPT_NAME']));
            if ($methodUsed == 'POST' && $referer == $thisScript) {
                return TRUE;
            }
            return FALSE;
        }

        /////////////////////////////////////
        // Return a boolean from a string.

        function stringToBoolean($value) {
            switch(strtoupper($value)) {
                case 'TRUE': return TRUE;
                case 'FALSE': return FALSE;
                default: return NULL;
            }
        }

     }
?>
