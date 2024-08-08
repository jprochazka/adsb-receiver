<?php
    // Start session
    session_start();

    // Load the common PHP classes.
    require_once('classes/common.class.php');
    require_once('classes/template.class.php');
    require_once('classes/acars.class.php');

    $common = new common();
    $template = new template();
    $acars = new acars();

    $pageData = array();

    // The title of this page.
    $pageData['title'] = "ACARS Messages";

    // Get most recent ACARS messages.
    $acarsMessages = $acars->getAcarsMessages(25, 0);

    $template->display($pageData);
?>
