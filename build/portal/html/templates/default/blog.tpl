{*

    ////////////////////////////////////////////////////////////////////////////////
    //                  ADS-B FEEDER PORTAL TEMPLATE INFORMATION                  //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: blog.tpl                                                    //
    // Version: 2.0.0                                                             //
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

*}
{area:head/}
{area:contents}
            <div class="container">
                <h1>Blog Posts</h1>
                <hr />
                {foreach $posts as $post}
                <h2><a href="post.php?title=<?php echo urlencode($post['title']) ?>">{post:title}</a></h2>
                <p>Posted <strong>{post:date}</strong> by <strong>{post:author}</strong>.</p>
                <div>{post:contents}</div>
                {/foreach}
                <ul class="pagination">
                {while pageNumber eq 0 | pageNumber lteq page:pageLinks}
                    <li><a href="?page={pageNumber}">{pageNumber}</a></li>
                {/while}
                </ul>
            </div>
{/area}
{area:scripts/}