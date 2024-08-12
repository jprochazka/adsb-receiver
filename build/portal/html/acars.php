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

    // Pagination.
    $items_per_page = 15;
    $page = (isset($_GET['page']) ? $_GET['page'] : 1);
    $message_count = $acars->getAcarsMessageCount();

    // Get most recent ACARS messages.
    $messages = $acars->getAcarsMessages($items_per_page, ($items_per_page * $page));
    $pageData['acarsMessages'] = $messages;

    // Calculate the number of pagination links to show.
    $pageData['pageLinks'] = ceil($message_count / $items_per_page);

    $template->display($pageData);
?>
