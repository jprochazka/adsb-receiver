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

    // Get the requested blog post.
    $post = $blog->getPostByTitle(urldecode($_GET['title']));

    // The title of this page.
    $pageData['title'] = $post['title'];

    // Add blog post data to the $pageData array.
    $pageData['postTitle'] = $post['title'];
    $pageData['postAuthor'] = $common->getAdminstratorName($post['author']);
    $pageData['postContents'] = $post['contents'];

    // Properly format the date and convert to slected time zone.
    $date = new DateTime($post['date'], new DateTimeZone('UTC'));
    $date->setTimezone(new DateTimeZone($common->getSetting('timeZone')));
    $pageData['postDate'] = $date->format($common->getSetting('dateFormat'));

    $template->display($pageData);
?>
