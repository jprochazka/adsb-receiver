<?php

    /////////////////////////////////////////////////////////////////////////////////////
    //                             ADS-B FEEDER PORTAL                                 //
    // =============================================================================== //
    // Copyright and Licensing Information:                                            //
    //                                                                                 //
    // The MIT License (MIT)                                                           //
    //                                                                                 //
    // Copyright (c) 2015 Joseph A. Prochazka                                          //
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

    $passwordIncorrect = FALSE;
    $didNotMatch = FALSE;

    // Load the require PHP classes.
    require_once('classes/common.class.php');
    require_once('classes/account.class.php');

    $common = new common();
    $account = new account();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php?origin=".urlencode('account.php'));
    }

    if ($common->postBack()) {
        // Check that the user supplied a password matching the one currently stored in administrators.xml.
        $authenticated = $account->authenticate($_SESSION['login'], $_POST['password'], FALSE, FALSE);
        
        if (!$authenticated)
            $passwordIncorrect = TRUE;
        if ($_POST['password1'] != $_POST['password2'])
            $didNotMatch = TRUE;

        if ($authenticated && $_POST['password1'] == $_POST['password2']) {
            // Change the password stored in administrators.xml related to this users login.
            $account->changePassword($_SESSION['login'], $_POST['password1']);
            // Since the password has changed we will log the user out to clear older session variables.
            $account->logout();
        }
    }

    require_once('includes/header.inc.php');

    /////////////////////
    // BEGIN HTML BODY //

    if ($_SESSION['firstLogin'] && !$common->postBack()) {
?>
            <div id="first-login-modal" class="modal fade in" role="dialog">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-body">
                            <strong>First time login detected.</strong><br />
                            You must change the default password before continuing.
                        </div>
                    </div>
                </div>
            </div>
            <script>
                $('#first-login-modal').modal('show');
            </script>
<?php
    }
?>
        <h1>Account Management</h1>
        <hr />
        <h2>Change Password</h2>
        <form id="change-password" method="post" action="account.php">
            <div class="form-group">
                <input type="password" class="form-control" name="password" id="password" placeholder="Current Password" required>
            </div>
            <div class="form-group">
                <input type="password" class="form-control" name="password1" id="password1" placeholder="New Password" required>
            </div>
            <div class="form-group">
                <input type="password" class="form-control" name="password2" id="password2" placeholder="Confirm Password" required>
            </div>
            <input type="submit" class="btn btn-default" value="Change Password">
<?php
    if ($passwordIncorrect || $didNotMatch) {
?>
            <div id="failure-alert" class="alert alert-danger" role="alert">
                <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
                <?php ($passwordIncorrect ? print "You did not supply the correct current password for this account." : ''); ?>
                <?php ($_SESSION['firstLogin'] || $passwordIncorrect && $didNotMatch ? print "<br />" : ''); ?>
                <?php ($didNotMatch ? print "You must change your current password before continuing." : ''); ?>
            </div>
<?php
    }
?>
        </form>
<?php

    // END HTML BODY //
    ///////////////////

    require_once('includes/footer.inc.php');
?>
