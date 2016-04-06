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
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."account.class.php");

    $common = new common();
    $settings = new settings();
    $account = new account();

    // Check if the user is already logged in.
    if ($account->isAuthenticated()) {
        if (isset($_REQUEST['origin'])) {
            // Redirect the authenticated visitor to their original destination.
            header ("Location: ".urldecode($_REQUEST['origin']));
        } else {
            // Redirect the user to the administration homepage.
            header ("Location: index.php");
        }
    }

    if ($common->postBack()) {
        $validToken = FALSE;

        // Look up the login using the supplied token.
        $login = $account->getLoginUsingToken($_POST['token']);

        if (!is_null($login)) {
            $validToken = TRUE;

            // Check the length of the password.
            $tooShort = TRUE;
            if (isset($_POST['password1']) && strlen($_POST['password1']) >= $settings::sec_length)
                $tooShort = FALSE;

            // Check that the supplied new passwords match.
            $notMatching = TRUE;
            if ($_POST['password1'] == $_POST['password2'])
                $notMatching = FALSE;

            // If everything associated with passwords is validated change the password.
            if (!$tooShort && !$notMatching) {
                // Change the password stored in administrators.xml related to this users login.
                $account->setToken($login);
                $account->changePassword($login, password_hash($_POST['password1'], PASSWORD_DEFAULT));
                header ("Location: login.php");
            }
        }
    }

    /////////////////////
    // BEGIN HTML BODY //

?>
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8" />
        <title></title>
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" />
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap-theme.min.css" />
        <link rel="stylesheet" href="assets/css/reset.css" />
    </head>
    <body>
        <div class="container">
            <form class="form-reset" method="post" action="reset.php">
                <h2 class="form-reset-heading">Reset Password</h2>
                <div>
                    <label for="token" class="sr-only">Token</label>
                    <input type="text" id="token" name="token" class="form-control" placeholder="Token" <?php (isset($_GET['token']) == "eth0" ? print 'value="'.$_GET['token'].'" ' : ''); ?>required autofocus>
                </div>
                <div>
                    <label for="password1" class="sr-only">Password</label>
                    <input type="password" id="password1" name="password1" class="form-control" placeholder="Password" required>
                </div>
                <div>
                    <label for="password2" class="sr-only">Confirm Password</label>
                    <input type="password" id="password2" name="password2" class="form-control" placeholder="Confirm password" required>
                </div>
                <div class="spacer"></div>
                <input type="submit" value="Reset Password" class="btn btn-lg btn-primary btn-block">
<?php
    // If authentication failed display the following error message.
    if ($common->postBack() && !$validToken) {
?>
                <div class="alert alert-danger" role="alert" id="failure-alert">
                    <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                    The supplied token is wrong or has already been used.
                </div>
<?php
    }
?>
            </form>
        </div>
        <script type="text/javascript" src="//code.jquery.com/jquery-2.1.4.min.js"></script>
        <script type="text/javascript" src="//maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"></script>
    </body>
</html>
<?php

    // END HTML BODY //
    ///////////////////
?>
