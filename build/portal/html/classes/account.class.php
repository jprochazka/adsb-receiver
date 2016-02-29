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

    class account {

        // Authentication
        ////////////////////

        // Check if the administrator is authenticated or not.
        function isAuthenticated() {
            // Check if the remeber me cookie is set and if so set sessions variables using the stored values.
            if (isset($_COOKIE['login']) && isset($_COOKIE['authenticated']) && $_COOKIE['authenticated']) {
                $_SESSION['authenticated'] = TRUE;
                $_SESSION['login'] = $_COOKIE['login'];
            } else {
                // Unset any cookies pertaining to user authentication since something is wrong or missing.
                unset($_COOKIE["authenticated"]);
                unset($_COOKIE["login"]);
            }
            // Make sure that the session variable Authenticated is set to TRUE and that the session Login variable is set.
            if (isset($_SESSION['login']) && isset($_SESSION['authenticated']) && $_SESSION['authenticated']) {
                return TRUE;
            }
            return FALSE;
        }

        // Authenticate an administrator by comparing their supplied login and password with the ones stored in administrators.xml.
        function authenticate($login, $password, $remember = FALSE, $forward = TRUE, $origin = NULL) {
            $common = new common();
            // Get all the administrators from the administrators.xml file.
            $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/administrators.xml") or die("Error: Cannot create administrators object");
            foreach ($administrators as $administrator) {
                // If or when we get to a matching login compare the supplied password to the one stored inadministrators.xml.
                if ($administrator->login == $login) {
                    if (password_verify($password, $administrator->password)) {
                        // Set the session variable Authenticated to TRUE and assign the variable Login the supplied login.
                        $_SESSION['authenticated'] = TRUE;
                        $_SESSION['login'] = $login;
                        // If the user wishes to be remembered set a cookie containg the authenticated and login variables.
                        if ($remember) {
                            setcookie("authenticated", TRUE, time() + (10 * 365 * 24 * 60 * 60));
                            setcookie("login", $login, time() + (10 * 365 * 24 * 60 * 60));
                        }
                        // Forward the user if the $forward variable is set to TRUE.
                        if ($forward) {
                            if (isset($origin)) {
                                // Redirect the authenticated visitor to their original destination.
                                header ("Location: ".urldecode($origin));
                            } else {
                                // Redirect the user to the administration homepage.
                                header ("Location: index.php");
                            }
                        }
                        return TRUE;
                    }
                }
            }
            // If things got this far authentication failed.
            return FALSE;
        }

        // Logs the user out by deleting current session varialbes related to administrative functions.
        function logout() {
            // Unset any session variables pertaining to user authentication.
            unset($_SESSION['authenticated']);
            unset($_SESSION['login']);
            // Unset any cookies pertaining to user authentication.
            unset($_COOKIE["authenticated"]);
            unset($_COOKIE["login"]);
            // Redirect the user to the main homepage.
            header ("Location: login.php");
        }

        // Change administrator settings.
        ////////////////////////////////////

        // Change the name associated to an existing administrator in the file administrators.xml.
        function changeName($login, $name) {
            $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/administrators.xml") or die("Error: Cannot create administrators object");
            foreach ($administrators->xpath("administrator[login='".$login."']") as $administrator) {
                $administrator->name = $name;
            }
            file_put_contents($_SERVER['DOCUMENT_ROOT']."/data/administrators.xml", $administrators->asXML());
        }

        // Change the name associated to an existing administrator in the file administrators.xml.
        function changeEmail($login, $email) {
            $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/administrators.xml") or die("Error: Cannot create administrators object");
            foreach ($administrators->xpath("administrator[login='".$login."']") as $administrator) {
                $administrator->email = $email;
            }
            file_put_contents($_SERVER['DOCUMENT_ROOT']."/data/administrators.xml", $administrators->asXML());
        }

        // Change a password stored for an existing administrator in the file administrators.xml.
        function changePassword($login, $password) {
            $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/administrators.xml") or die("Error: Cannot create administrators object");
            foreach ($administrators->xpath("administrator[login='".$login."']") as $administrator) {
                $administrator->password = password_hash($password, PASSWORD_DEFAULT);
            }
            file_put_contents($_SERVER['DOCUMENT_ROOT']."/data/administrators.xml", $administrators->asXML());
        }

    }
?>
