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
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."links.class.php");

    $common = new common();
    $account = new account();
    $links = new links();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php");
    }

    $nameExists = FALSE;
    if ($common->postBack()) {
        // Check if the name already exists.
        $nameExists = $links->nameExists($_POST['name']);

        if (!$nameExists) {
            // Add this link..
            $links->addLink($_SESSION['name'], $_POST['address']);

            // Forward the user to the link management index page.
            header ("Location: /admin/links/");
        }
    }

    ////////////////
    // BEGIN HTML

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");
?>
            <h1>Links Management</h1>
            <hr />
            <h2>Add Link</h2>
            <form id="add-link" method="post" action="add.php">
                <div class="form-group">
                    <label for="name">Name</label>
                    <input type="text" id="name" name="name" class="form-control"<?php echo (isset($_POST['name']) ? ' value="'.$_POST['name'].'"' : '')?> required>
<?php
    if ($nameExists) {
?>
                    <div class="alert alert-danger" role="alert" id="failure-alert">
                        <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                            <span aria-hidden="true">&times;</span>
                        </button>
                        Name already exists.
                    </div>
<?php
    }
?>
                </div>
                <div class="form-group">
                    <label for="address">Address</label>
                    <input type="text" id="address" name="address" class="form-control"<?php echo (isset($_POST['address']) ? ' value="'.$_POST['address'].'"' : '')?> required>
                </div>
<?php
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>
