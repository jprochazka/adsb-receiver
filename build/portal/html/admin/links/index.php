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

    // Get all links.
    $allLinks = $links->getAllLinks();

    ////////////////
    // BEGIN HTML

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");
?>

            <h1>Links Management</h1>
            <hr />
            <h2>Links</h2>
            <a href="add.php" class="btn btn-info" style="margin-bottom:  10px;" role="button">Add Link</a>
            <div class="table-responsive">
                <table class="table table-striped table-condensed">
                    <tr>
                        <th></th>
                        <th>Name</th>
                        <th>Address</th>
                    </tr>
<?php
    foreach ($links as $link) {
?>
                    <tr>
                        <td><a href="edit.php?name=<?php echo urlencode($link['name']); ?>">edit</a> <a href="delete.php?title=<?php echo urlencode($link['name']); ?>">delete</a></td>
                        <td><?php echo $link['name']; ?></td>
                        <td><a href="<?php echo $link['address']; ?>" target="_blank"><?php echo $link['address']; ?></a></td>
                    </tr>
<?php
    }
?>
                </table>
            </div>
<?php
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>
