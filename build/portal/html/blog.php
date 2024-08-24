<?php
    // Start session
    session_start();

    // Load the common PHP classes.
    require_once('classes/common.class.php');
    require_once('classes/template.class.php');
    require_once('classes/blog.class.php');

    $common = new common();
    $template = new template();
    $blog = new blog();

    $pageData = array();

    // The title of this page.
    $pageData['title'] = "Blog";

    // Get all blog posts from the XML file storing them.
    $allPosts = $blog->getAllPosts();

    // Format the post dates according to the related setting.
    foreach ($allPosts as &$post) {
        if (strpos($post['contents'], '{more}') !== false) {
            $post['contents'] = substr($post['contents'], 0, strpos($post['contents'], '{more}'));
        }
        $post['author'] = $common->getAdminstratorName($post['author']);

        // Properly format the date and convert to slected time zone.
        $date = new DateTime($post['date'], new DateTimeZone('UTC'));
        $date->setTimezone(new DateTimeZone($common->getSetting('timeZone')));
        $post['date'] = $date->format($common->getSetting('dateFormat'));
    }

    // Pagination.
    $itemsPerPage = 5;
    $page = (isset($_GET['page']) ? $_GET['page'] : 1);
    $pageData['blogPosts'] = $common->paginateArray($allPosts, $page, $itemsPerPage - 1);

    // Calculate the number of pagination links to show.
    $pageData['pageLinks'] = ceil(count($allPosts) / $itemsPerPage);

    $template->display($pageData);
?>
