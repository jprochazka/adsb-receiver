<!DOCTYPE html>
<html lang="en">
    <head>
    <meta charset="utf-8">
    <title>ADS-B Receiver Administration</title>
        <meta http-equiv="cache-control" content="no-cache" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="/admin/assets/css/bootstrap.min.css">
        <link rel="stylesheet" href="/admin/assets/css/bootstrap-theme.min.css">
<?php if (basename($_SERVER['PHP_SELF']) == "index.php") { ?>
        <link rel="stylesheet" href="/admin/assets/css/jquery.datetimepicker.css">
<?php } ?>
        <link rel="stylesheet" href="/admin/assets/css/admin.css">
        <script src="/admin/assets/js/jquery-2.2.1.min.js"></script>
        <script src="/admin/assets/js/bootstrap.min.js"></script>
<?php if (basename($_SERVER['PHP_SELF']) == "index.php") { ?>
        <script src="/admin/assets/js/index.js"></script>
        <script src="/admin/assets/js/jquery.datetimepicker.full.min.js"></script>
<?php } ?>
<?php if (basename($_SERVER['PHP_SELF']) == "account.php") { ?>
        <script src="/admin/assets/js/jquery.validate.min.js"></script>
        <script src="/admin/assets/js/account.js"></script>
<?php } ?>
    </head>
        <body>
        <div id="wrapper">
            <nav class="navbar navbar-default navbar-fixed-top" role="navigation">
                <div class="container">
                    <div class="navbar-header">
                        <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
                            <span class="sr-only">Toggle navigation</span>
                            <span class="icon-bar"></span>
                            <span class="icon-bar"></span>
                            <span class="icon-bar"></span>
                        </button>
                        <a class="navbar-brand" href="/admin">ADS-B Receiver Administration</a>
                    </div>
                    <div class="navbar-collapse collapse">
                        <ul class="nav navbar-nav">
                            <li id="logout-link"><a href="/admin">Settings</a></li>
                            <li id="logout-link"><a href="/admin/blog">Blog</a></li>
                            <li id="logout-link"><a href="/admin/account.php">Account</a></li>
                            <li id="logout-link"><a href="/admin/logout.php">Logout</a></li>
                            <li id="logout-link"><a href="/" target="_blank">Portal Home</a></li>
                        </ul>
                    </div>
                </div>
            </nav>
            <div class="container">
