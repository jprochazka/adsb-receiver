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

    require_once('includes/header.inc.php')
?>
        <form method="post" action="index.php">
            <div class="panel panel-default">
                <div class="panel-heading">General Settings</div>
                <div class="panel-body">
                    <div class="form-group">
                        <label for="siteName">Site Name</label>
                        <input type="text" class="form-control" id="siteName" name="siteName">
                    </div>
                    <div class="form-group">
                        <label for="template">Template</label>
                        <select class="form-control" id="template" name="template">
                            <option value="default">default</option>
                        </select>
                    </div>
                </div>
            </div>
            <div class="panel panel-default">
                <div class="panel-heading">Navigation Settings</div>
                <div class="panel-body">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="enableGraphs" value="TRUE"> Enable dump1090 map link.
                        </label>
                    </div>
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="enableDump1090" value="TRUE"> Enable dump1090 map link.
                        </label>
                    </div>
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="enableDump978" value="TRUE"> Enable dump978 map link.
                        </label>
                    </div>
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="enablePfclient" value="TRUE"> Enable Planfinder ADS-B Client link.
                        </label>
                    </div>
                </div>
            </div>
        </form>
<?php
    require_once('includes/footer.inc.php')
?>