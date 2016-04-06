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

    $common = new common();
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
        // Check that a vailid login was supplied.
        $validLogin = $account->loginExists($_POST['login']);
        $emailSent = FALSE;

        if ($validLogin) {
            // Set a new token for the user.
            $token = $account->setToken($_POST['login']);

            // Create and send the email.
            $subject = $common->getSetting("siteName")." Password Reset Request";
            $message  = "A password reset request has been received by your ADS-B portal.\r\n";
            $message .= "\r\n";
            $message .= "If you did not request this password reset simply disregard this email.\r\n";
            $message .= "If in fact you did request a password reset follow the link below to do so.\r\n";
            $message .= "\r\n";
            $message .= "http://".$_SERVER['HTTP_HOST']."/admin/reset.php?token=".$token."\r\n";
            $message .= "\r\n";
            $message .= "Your password reset token is: ".$token;

            $emailSent = $common->sendEmail($account->getEmail($_POST['login']), $subject, $message);
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
        <link rel="stylesheet" href="assets/css/forgot.css" />
    </head>
    <body>
<?php
    // If authentication failed display the following error message.
    if ($common->postBack() && $emailSent) {
?>
        <div class="container">
            <h2>Confirmation Email Sent</h2>
            <p>
                An email containing a link and confirmation token has been sent via email to the address associated with the supplied login.
                Please follow the instructions in this email in order to complete the password reset process.
            </p>
        </div>

<?php
    } else {
?>
        <div class="container">
            <form class="form-signin" method="post" action="forgot.php">
                <h2 class="form-signin-heading">Reset Password</h2>
                <div>
                    <label for="login" class="sr-only">Login</label>
                    <input type="text" id="login" name="login" class="form-control" placeholder="Login" required autofocus>
                </div>
                <div class="spacer"></div>
                <input type="submit" value="Submit" class="btn btn-lg btn-primary btn-block">
            </form>
        </div>
<?php
        // If authentication failed display the following error message.
        if ($common->postBack() && !$validLogin) {
?>
                <div class="alert alert-danger" role="alert" id="failure-alert">
                    <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                    The supplied login does not exist.
                </div>
<?php
        }

        // If the email failed to be sent display the following error message.
        if ($common->postBack() && !$emailSent) {
?>
                <div class="alert alert-danger" role="alert" id="failure-alert">
                    <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                    There was a problem sending the confirmation email.
                </div>
<?php
        }
    }
?>
        <script type="text/javascript" src="//code.jquery.com/jquery-2.1.4.min.js"></script>
        <script type="text/javascript" src="//maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"></script>
    </body>
</html>
<?php

    // END HTML BODY //
    ///////////////////
?>

