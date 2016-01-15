<?php

    /*
    #####################################################################################
    #                                   ADS-B FEEDER                                    #
    #####################################################################################
    #                                                                                   #
    #  A set of scripts created to automate the process of installing the software      #
    #  needed to setup a Mode S decoder as well as feeders which are capable of         #
    #  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
    #                                                                                   #
    #  Project Hosted On GitHub: https://github.com/jprochazka/adsb-feeder              #
    #                                                                                   #
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    #                                                                                   #
    # Copyright (c) 2015 Joseph A. Prochazka                                            #
    #                                                                                   #
    # Permission is hereby granted, free of charge, to any person obtaining a copy      #
    # of this software and associated documentation files (the "Software"), to deal     #
    # in the Software without restriction, including without limitation the rights      #
    # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
    # copies of the Software, and to permit persons to whom the Software is             #
    # furnished to do so, subject to the following conditions:                          #
    #                                                                                   #
    # The above copyright notice and this permission notice shall be included in all    #
    # copies or substantial portions of the Software.                                   #
    #                                                                                   #
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
    # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
    # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
    # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
    # SOFTWARE.                                                                         #
    #                                                                                   #
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    */

    session_start();

    echo "Authenticated: ".$_SESSION['authenticated'].'<br />';
    echo "Login: ".$_SESSION['login'].'<br />';
    echo "First Login: ".$_SESSION['firstLogin'].'<br />';

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

        echo "POSTBACK!";

        // Check that the user supplied a password matching the one currently stored in administrators.xml.
        $authenticated = $account->authenticate($_SESSION['login'], $_POST['password'], FALSE, FALSE);
        // Check that the supplied passwords match.
        if ($authenticated && $_POST['password1'] == $_POST['password2']) {

            echo "AUTHENTICATED!";

            // Change the password stored in administrators.xml related to this users login.
            $account->changePassword($_SESSION['login'], $_POST['password1']);
            // Since the password has changed we will log the user out to clear older session variables.
            $account->logout();
        }
    }

    require_once('includes/header.include.php');

    /////////////////////
    // BEGIN HTML BODY //

?>
        <div>You must change your current password before continuing.</div>
        <div>The password for this account has been changed successfully.</div>
        <div>You must supply the correct current password for this account.</div>
        <div>The passwords supplied for the new password did not match.</div>

        <form method="post" action="account.php">
            <div>
                <label for="password">Current Password:</label>
                <input type="password" name="password">
            </div>
            <div>
                <label for="password1">New Password:</label>
                <input type="password" name="password1">
            </div>
            <div>
                <label for="password2">Confirm Password:</label>
                <input type="password" name="password2">
            </div>
            <input type="submit" value="Change Password">
        </form>
<?php

    // END HTML BODY //
    ///////////////////

    require_once('includes/footer.include.php');
?>
