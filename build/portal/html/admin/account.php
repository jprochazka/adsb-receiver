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

    $passwordIncorrect = FALSE;
    $didNotMatch = FALSE;

    // Load the require PHP classes.
    require_once('../classes/common.class.php');
    require_once('../classes/account.class.php');

    $common = new common();
    $account = new account();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php?origin=".urlencode('account.php'));
    }

    if ($common->postBack()) {
        // Check that a name was supplied.
        if (empty($_POST['name']))
            $noName = TRUE;

        // Check that a vailid email address was supplied.
        if (!filter_var($_POST['email'], FILTER_VALIDATE_EMAIL))
            $invalidEmail = TRUE;

        // Check that all password reset data was supplied.
        if (!empty($_POST['password']) || !empty($_POST['password1']) || !empty($_POST['password2'])) {
        
            // Process a password change request if the existing and new password were supplied.
            if (!empty($_POST['password1']) && !empty($_POST['password1']) && !empty($_POST['password2'])) {
                
                // Check that the user supplied a password matching the one currently stored in administrators.xml.
                $authenticated = $account->authenticate($_SESSION['login'], $_POST['password'], FALSE, FALSE);
                if (!$authenticated)
                    $passwordIncorrect = TRUE;
                if ($_POST['password1'] != $_POST['password2'])
                    $notMatching = TRUE;

                if ($authenticated && $_POST['password1'] == $_POST['password2']) {
                    // Change the password stored in administrators.xml related to this users login.
                    $account->changePassword($_SESSION['login'], $_POST['password1']);

                    // Since the password has changed we will log the user out to clear older session variables.
                    $account->logout();
                }
            }
        } else {
            // Only partial data was supplied to change the current password.
            if (!empty($_POST['password']))
                $noCurrent = TRUE;
            if (!empty($_POST['password1']) || !empty($_POST['password2']))
                $passwordMissing = TRUE;
        }

        // If validation passed make the requested changes to the administrator account data.
        if (!$noName && !$invalidEmail && !$passwordIncorrect && !$noCurrent && !$notMatching && !$passwordMissing) {
            $account->changeName($_SESSION['login'], $_POST['name'])
            $account->changeEmail($_SESSION['login'], $_POST['email'])
            if (!empty($_POST['password1']) && !empty($_POST['password1']) && !empty($_POST['password2']))
                $account->changePassword($_SESSION['login'], $_POST['password1']);
        }
    }

    require_once('includes/header.inc.php');

    /////////////////////
    // BEGIN HTML BODY //

?>
        <h1>Account Management</h1>
        <hr />
<?php
    if ($passwordIncorrect || $didNotMatch) {
?>
            <div id="failure-alert" class="alert alert-danger" role="alert">
                <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
                <?php ($noName ? print "You must supply a name to associate with this account.<br />" : ''); ?>
                <?php ($invalidEmail ? print "You must supply a valid email address to associate with this account.<br />" : ''); ?>
                <?php ($passwordIncorrect || $noCurrent ? print "You did not supply the correct current password for this account.<br />" : ''); ?>
                <?php ($notMatching || $passwordMissing ? print "The password and password confirmation did not match or are missing.<br />" : ''); ?>
            </div>
<?php
    }
?>
        <h2>Change Password</h2>
        <form id="change-password" method="post" action="account.php">

            <div class="panel panel-default">
                <div class="panel-heading">Account Settings</div>
                <div class="panel-body">
                    <div class="form-group">
                        <input type="text" class="form-control" name="login" id="login" placeholder="Login" disabled>
                    </div>
                    <div class="form-group">
                        <input type="text" class="form-control" name="name" id="name" placeholder="Name" required>
                    </div>
                    <div class="form-group">
                        <input type="email" class="form-control" name="email" id="email" placeholder="Email Address" required>
                    </div>
                </div>
            </div>

            <div class="panel panel-default">
                <div class="panel-heading">Change Password</div>
                <div class="panel-body">
                    <div class="form-group">
                        <input type="password" class="form-control" name="password" id="password" placeholder="Current Password" required>
                    </div>
                    <div class="form-group">
                        <input type="password" class="form-control" name="password1" id="password1" placeholder="New Password" required>
                    </div>
                    <div class="form-group">
                        <input type="password" class="form-control" name="password2" id="password2" placeholder="Confirm Password" required>
                    </div>
                </div>
            </div>

            <input type="submit" class="btn btn-default" value="Submit">
        </form>
<?php

    // END HTML BODY //
    ///////////////////

    require_once('includes/footer.inc.php');
?>
