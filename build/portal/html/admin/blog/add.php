<?php

    /////////////////////////////////////////////////////////////////////////////////////
    //                             ADS-B FEEDER PORTAL                                 //
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
        // Update the contents of the blog post.
        $blog->addPost($_SESSION['login'], $_POST['title'], $_POST['contents']);

        // Forward the user to the blog management index page.
        header ("Location: /admin/blog/");
    }

    ////////////////
    // BEGIN HTML

    require_once('../includes/header.inc.php');
?>
            <h1>Blog Management</h1>
            <hr />
            <h2>Add Blog Post</h2>
            <form id="add-blog-post" method="post" action="add.php">
                <div class="form-group">
                    <label for="title">Title</label>
                    <input type="text" id="title" name="title" class="form-control" required>
                </div>
                <div class="form-group">
                    <textarea id="contents" name="contents"></textarea>
                </div>
                <input type="submit" class="btn btn-default" value="Publish">
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
                    toolbar: 'insertfile undo redo | styleselect | bold italic | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | link image moreButton',
                    setup: function (editor) {
                        editor.addButton('moreButton', {
                            type: 'button',
                            text: 'Read more...',
                            icon: false,
                            onclick: function () {
                                editor.execCommand('mceInsertContent', false, "{more}");
                            }
                        });
                    }
                });
            </script>
<?php
    require_once('../includes/footer.inc.php');
?>
