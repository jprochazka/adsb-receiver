<?php

    ////////////////////////////////////////////////////////////////////////////////
    //                  ADS-B FEEDER PORTAL TEMPLATE INFORMATION                  //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: master                                                      //
    // Version: 1.0.0                                                             //
    // Release Date:                                                              //
    // Author: Joe Prochazka                                                      //
    // Website: https://www.swiftbyte.com                                         //
    // ========================================================================== //
    // Copyright and Licensing Information:                                       //
    //                                                                            //
    // Copyright (c) 2015 Joseph A. Prochazka                                     //
    //                                                                            //
    // This template set is licensed under The MIT License (MIT)                  //
    // A copy of the license can be found package along with these files.         //
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////
    // Additional <head> content.
    function headContent() { }

    ///////////////////
    // Page content.
    function pageContent() {
        $common = new common();
        global $posts, $pageLinks, $previewLength;
?>
            <div class="container">
                <h1>Blog Posts</h1>
                <hr />
<?php
        foreach ($posts as $post) {
?>
                <h2><a href="post.php?title=<?php echo urlencode($post['title']) ?>"><?php echo $post['title']; ?></a></h2>
                <p>Posted <strong><?php echo date_format(date_create($post['date']), "F jS, Y"); ?></strong> by <strong><?php echo $post['author']; ?></strong>.</p>
                <div><?php echo substr($common->removeHtmlTags($post['contents']), 0, $previewLength); ?></div>

<?php
        }
?>
                <ul class="pagination">
<?php
    $i = 1;
    while ($i <= $pageLinks) {
?>
                    <li><a href="?page=<?php echo $i; ?>"><?php echo $i; ?></a></li>
<?php
        $i++;
    }
?>
                </ul>
            </div>
<?php
    }

    /////////////////////////////////////////////////
    // Content to be added to the scripts section.
    function scriptContent() {}
?>