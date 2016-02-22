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

    require_once('classes/settings.class.php');
    $settings = new settings();

    // The most current stable release.
    $currentRelease = "2016-02-18";

    // Begin the upgrade process if this release is newer than what is installed.
    if ($currentRelease > settings::thisRelease) {
        header ("Location: upgrade.php");
    }

    // Begin Installation
    ////////////////////////

    $applicationDirectory = preg_replace( '~[/\\\\][^/\\\\]*$~', DIRECTORY_SEPARATOR, getcwd());

    if (is_writable($applicationDirectory.'data')) {

    }
?>

<!-- DATA STORAGE -->

<select name="databaseType">
    <option value="xml">XML</option>
    <option value="sqlite">SQLite</option>
    <option value="mysql">MySQL</option>
    <option value="pgsql">PostgreSQL</option>
    <option value="sqlsrv">Microsoft SQL Server</option>
</select>

<label for="dbHost">Database Server</label>
<input type="text" name="dbHost">

<label for="dbUser">Database User</label>
<input type="text" name="dbUser">

<label for="dbPassword">Database Password</label>
<input type="password" name="dbPassword">

<label for="dbName">Database Name</label>
<input type="text" name="dbName">

<label for="dbPrefix">Database Prefix</label>
<input type="text" name="dbPrefix">

<input type="submit" name="testConnection" value="Test Connection">

<!-- ADMINISTRATOR -->

<label for="adminName">Administrator Name</label>
<input type="text" name="adminName">

<label for="adminEmail">Administrator Email Address</label>
<input type="text" name="adminEmail">

<label for="AdminLogin">Administrator Login</label>
<input type="text" name="AdminLogin">

<label for="adminPassword1">Administrator Password</label>
<input type="password" name="adminPassword1">

<label for="adminPassword2">Repeat Password</label>
<input type="password" name="adminPassword2">

<input type="submit" name="createAccount" value="Create Account">