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
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."account.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."blog.class.php");

    $common = new common();
    $account = new account();
    $blog = new blog();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php");
    }

    // Set updated variable to FALSE.
    $updated = FALSE;

    if ($common->postBack()) {
        // Update the contents of the blog post.
        $blog->editContentsByTitle(urldecode($_GET['title']), $_POST['contents']);

        // Set updated to TRUE since settings were updated.
        $updated = TRUE;
    }

    // Get titles and dates for all blog posts.
    $post = $blog->getPostByTitle(urldecode($_GET['title']));

    ////////////////
    // BEGIN HTML

    require_once('../includes/header.inc.php');

    // Display the updated message if settings were updated.
    if ($updated) {
?>
        <div id="contents-saved" class="alert alert-success fade in" role="alert">
            <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
            Blog post contents have been updated.
        </div>
<?php
    }
?>
            <h1>Blog Management</h1>
            <hr />
            <h2>Edit Blog Post</h2>
            <h3><?php echo $post['title']; ?></h3>
            <p>Posted <strong><?php echo date_format(date_create($post['date']), "F jS, Y"); ?></strong> by <strong><?php echo $common->getAdminstratorName($post['author']); ?></strong>.</p>
            <form id="edit-blog-post" method="post" action="edit.php?title=<?php echo urlencode($post['title']); ?>">
                <div class="form-group">
                    <textarea id="contents" name="contents"><?php echo $post['contents']; ?></textarea>
                </div>
                <input type="submit" class="btn btn-default" value="Commit Changes">
            </form>
            <script src='//cdn.tinymce.com/4/tinymce.min.js'></script>
            <script>
                tinymce.init({
                    selector: 'textarea',
                    height: 500,
                    plugins: [
                        'advlist autolink lists link image charmap print preview anchor',
                        'searchreplace visualblocks code fullscreen',
                        'insertdatetime media table contextmenu paste code'
                    ],
                    toolbar: 'insertfile undo redo | styleselect | bold italic | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | link image',
                    content_css: [
                        '//fast.fonts.net/cssapi/e6dc9b99-64fe-4292-ad98-6974f93cd2a2.css',
                        '//www.tinymce.com/css/codepen.min.css'
                    ]
                });
            </script>
<?php
    require_once('../includes/footer.inc.php');
?>
