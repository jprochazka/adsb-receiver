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

    session_start();

    // Load the require PHP classes.
    require_once('../../classes/common.class.php');
    require_once('../../classes/account.class.php');
    require_once('../../classes/blog.class.php');

    $common = new common();
    $account = new account();
    $blog = new blog();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php");
    }

    if ($common->postBack()) {
        // Delete the selected blog post.
        $blog->deletePostByTitle(urldecode($_GET['title']));

        // Forward the user to the blog management index page.
        header ("Location: /admin/blog/");
    }

    // Get titles and dates for all blog posts.
    $post = $blog->getPostByTitle(urldecode($_GET['title']));


    ////////////////
    // BEGIN HTML

    require_once('../includes/header.inc.php');

?>
            <h1>Blog Management</h1>
            <hr />
            <h2>Delete Blog Post</h2>
            <h3><?php echo $post->title; ?></h3>
            <p>Posted <strong><?php echo date_format(date_create($post->date), "F jS, Y"); ?></strong> by <strong><?php echo $post->author; ?></strong>.</p>
            <div class="alert alert-danger" role="alert">
                <p>
                    <strong>Confirm Delete</strong><br />
                    Are you sure you want to delete this blog post?
                </p>
            </div>
            <form id="delete-blog-post" method="post" action="delete.php?title=<?php echo urlencode($post->title); ?>">
                <input type="submit" class="btn btn-default" value="Delete Post">
                <a href="/admin/blog/" class="btn btn-info" role="button">Cancel</a>
            </form>
<?php
    require_once('../includes/footer.inc.php');
?>