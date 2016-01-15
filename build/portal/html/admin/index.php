<?php

    session_start();

    // Load the require PHP classes.
    require_once('classes/common.class.php');
    require_once('classes/account.class.php');

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
