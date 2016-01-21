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

    ///////////////////////////////
    // Default Login Information //
    ///////////////////////////////
    // Login: admin              //
    // Password: adsbfeeder      //
    ///////////////////////////////

    session_start();

    // Load the require PHP classes.
    require_once('../classes/common.class.php');
    require_once('../classes/account.class.php');

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
        // Try to authenticate the user using the credentials supplied.
        $remember = (isset($_POST['remember']) ? TRUE : FALSE);
        $origin = (isset($_REQUEST['origin']) ? $_REQUEST['origin'] : NULL);
        $authenticated = $account->authenticate($_POST['login'], $_POST['password'], $remember, TRUE, $origin);
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
        <link rel="stylesheet" href="assets/css/login.css" />
    </head>
    <body>
        <div class="container">
            <form class="form-signin" method="post" action="login.php">
                <h2 class="form-signin-heading">ADS-B Feeder Login</h2>
                <div>
                    <label for="login" class="sr-only">Login</label>
                    <input type="text" id="login" name="login" class="form-control" placeholder="Login" required autofocus>
                </div>
                <div>
                    <label for="password" class="sr-only">Password</label>
                    <input type="password" id="password" name="password" class="form-control" placeholder="Password" required autofocus>
                </div>
                <div class="checkbox">
                    <label>
                        <input type="checkbox" name="remember" value="TRUE"> Remember me
                    </label>
                </div>
                <input type="submit" value="Login" class="btn btn-lg btn-primary btn-block">
<?php
    // If authentication failed display the following error message.
    if ($common->postBack() && !$authenticated) {
?>
                <div class="alert alert-danger" role="alert" id="failure-alert">
                    <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                    Authentication failed.
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
