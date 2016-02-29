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

    require_once('../classes/settings.class.php');
    $settings = new settings();

    // THE FOLLOWING COMMENTED LINES WILL BE USED IN FUTURE RELEASES
    ///////////////////////////////////////////////////////////////////

    // The most current stable release.
    //$currentRelease = "2016-02-18";

    // Begin the upgrade process if this release is newer than what is installed.
    //if ($currentRelease > settings::thisRelease) {
    //    header ("Location: upgrade.php");
    //}

    // Check Folder and File Permissions
    ///////////////////////////////////////

    $applicationDirectory = preg_replace( '~[/\\\\][^/\\\\]*$~', DIRECTORY_SEPARATOR, getcwd());

    $writableData = FALSE;
    if (is_writable($applicationDirectory.'data'))
        $writableData = TRUE;

    $writeableClass = FALSE;
    if (is_writable($applicationDirectory.'classes/settings.class.php'))
        $writeableClass = TRUE;

    // Display HTML
    //////////////////

    require_once('includes/header.inc.php');
?>
<h1>ADS-B Receiver Portal Setup</h1>
<p>The following wizard will guide you through the setup process.</p>
<div class="padding"></div>
<form id="install-form">
    <div class="form-group">

        <h2>Directory Permissions</h2>
        <section>
            <div class="alert <?php echo ($writableData == TRUE ? 'alert-success' : 'alert-danger' ); ?>"><strong>/data</strong> is<?php echo ($writableData ? ' ' : ' not' ); ?> writable.</div>
            <div class="alert <?php echo ($writeableClass ? 'alert-success' : 'alert-danger' ); ?>"><strong>/classes/settings.class.php</strong> is<?php echo ($writeableClass ? ' ' : ' not' ); ?> writable.</div>
            <input type="hidden" name="permissions" id="permissions" value="<?php echo $writableData; ?>">
<?php if (!$writableData || !$writeableClass) {?>
            <p>
                Please fix the permissions for the following directory and/or file to make sure they are writable before proceeding.
                Once you have made the necessary changes please <a href="#" onclick="location.reload();">reload</a> this page to allow the installer to recheck permissions.
            </p>
<?php } ?>
        </section>

        <h2>Data Storage</h2>
        <section>
            <label for="driver">Database Type</label>
            <select class="form-control" name="driver" id="driver"> name="driver">
                <option value="xml">XML</option>
                <option value="sqlite">SQLite</option>
                <option value="mysql">MySQL</option>
                <option value="pgsql">PostgreSQL</option>
                <option value="sqlsrv">Microsoft SQL Server</option>
            </select>
            <div class="form-group" id="host-div">
                <label for="host">Database Server *</label>
                <input type="text" class="form-control" name="host" id="host" required>
            </div>
            <div class="form-group" id="username-div">
                <label for="username">Database User *</label>
                <input type="text" class="form-control" name="username" id="username" required>
            </div>
            <div class="form-group" id="password-div">
                <label for="password">Database Password *</label>
                <input type="password" class="form-control" name="password" id="password" required>
            </div>
            <div class="form-group" id="database-div">
                <label for="database" id="database-name">Database Name *</label>
                <input type="text" class="form-control" name="database" id="database" required>
            </div>
            <div class="form-group" id="prefix-div">
                <label for="prefix">Database Prefix</label>
                <input type="text" class="form-control" name="prefix" id="prefix" id="prefix">
            </div>
            <p id="required-p">(*) Required</p>
        </section>

        <h2>Administrator Account</h2>
        <section>
            <div class="form-group">
                <label for="adminName">Administrator Name *</label>
                <input type="text" class="form-control" name="name" required>
            </div>
            <div class="form-group">
                <label for="adminEmail">Administrator Email Address *</label>
                <input type="email" class="form-control" name="email" required>
            </div>
            <div class="form-group">
                <label for="AdminLogin">Administrator Login *</label>
                <input type="text" class="form-control" name="login" required>
            </div>
            <div class="form-group">
                <label for="adminPassword1">Administrator Password *</label> <span id="result"></span>
                <input type="password" class="form-control" class="form-control" name="password1" id="password1" required>
            </div>
            <div class="form-group">
                <label for="adminPassword2">Repeat Password *</label>
                <input type="password" class="form-control" name="password2" id="password2" required>
            </div>
            <p>(*) Required</p>
        </section>
    </div>
</form>

<?php
    require_once('includes/footer.inc.php');
?>