<?php
    session_start();

    // Load the require PHP classes.
    require_once('../classes/account.class.php');
    $account = new account();
    $account->logout();
?>