<?php
    // Start session
    session_start();

    // Load the common PHP classes.
    require_once('classes/common.class.php');
    $common = new common();

    // Get the default page from the settings.
    $defaultPage = $common->getSetting("defaultPage");

    // Forward the user to the default page defined in the settings.
    header ("Location: ".$defaultPage);
?>