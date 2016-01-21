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

    // Load the require PHP classes.
    require_once('../classes/common.class.php');
    require_once('../classes/account.class.php');

    $common = new common();
    $account = new account();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php");
    }

    echo "Authenticated: ".$_SESSION['authenticated'].'<br />';
    echo "Login: ".$_SESSION['login'].'<br />';
    echo "First Login: ".$_SESSION['firstLogin'].'<br />';
?>

<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8" />
        <title></title>
    </head>
    <body>
        index.php
    </body>
</html>
