<?php

    /////////////////////////////////////////////////////////////////////////////////////
    //                            ADS-B RECEIVER PORTAL                                //
    // =============================================================================== //
    // Copyright and Licensing Information:                                            //
    //                                                                                 //
    // The MIT License (MIT)                                                           //
    //                                                                                 //
    // Copyright (c) 2015-2016 Joseph A. Prochazka                                     //
    //                                                                                 //
    // Permission is hereby granted, free of charge, to any person obtaining a copy    //
    // of this software and associated documentation files (the "Software"), to deal   //
    // in the Software without restriction, including without limitation the rights    //
    // to use, copy, modify, merge, publish, distribute, sublicense, and/or sell       //
    // copies of the Software, and to permit persons to whom the Software is           //
    // furnished to do so, subject to the following conditions:                        //
    //                                                                                 //
    // The above copyright notice and this permission notice shall be included in all  //
    // copies or substantial portions of the Software.                                 //
    //                                                                                 //
    // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR      //
    // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,        //
    // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE     //
    // AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER          //
    // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,   //
    // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE   //
    // SOFTWARE.                                                                       //
    /////////////////////////////////////////////////////////////////////////////////////

    // Start session
    session_start();

echo pathinfo(__FILE__, PATHINFO_FILENAME);

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
    $pageData['pageLinks'] = count($allPosts) / $itemsPerPage;

    $template->display($pageData);
?>
