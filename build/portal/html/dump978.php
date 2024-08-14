<?php

    // Start session
    session_start();

    // Load the common PHP classes.
    require_once('classes/common.class.php');
    require_once('classes/template.class.php');

    $common = new common();
    $template = new template();

    $pageData = array();

    // The title of this page.
    $pageData['title'] = "Live Dump978 Map";

    $template->display($pageData);
?>
