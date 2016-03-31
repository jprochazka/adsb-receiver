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
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            // Retrieve this administrator's account data from where it is stored.
            $storedPassword = NULL;
            if ($settings::db_driver == "xml") {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators as $administrator) {
                    if ($administrator->login == $login) {
                        $storedPassword = $administrator->password;
                        break;
                    }
                }
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $common = new common();
                $dbh = $common->pdoOpen();
                $sql = "SELECT * FROM ".$settings::db_prefix."administrators WHERE login = :login";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->execute();
                $administrator = $sth->fetch();
                $sth = NULL;
                $dbh = NULL;
                $storedPassword = $administrator['password'];
            }

            // Compare the supplied password to the one stored inadministrators.xml.
            if (password_verify($password, $storedPassword)) {
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
                // If we got to this point then authentication succeeded.
                return TRUE;
            }
            // If we got this far authentication failed.
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

        // Add/delete administrator account.
        ///////////////////////////////////////

        function addAdministrator($name, $email, $login, $password) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                $administrator = $administrators->addChild('administrator', '');
                $administrator->addChild('name', $name);
                $administrator->addChild('email', $email);
                $administrator->addChild('login', $login);
                $administrator->addChild('password', $password);
                $dom = dom_import_simplexml($administrators)->ownerDocument;
                $dom->formatOutput = TRUE;
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml", $administrators->asXML());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "INSERT INTO ".$settings::db_prefix."administrators (name, email, login, password) VALUES (:name, :email, :login, :password)";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 100);
                $sth->bindParam(':email', $email, PDO::PARAM_STR, 75);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->bindParam(':password', $password, PDO::PARAM_STR, 255);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        // Get administrator settings.
        /////////////////////////////////

        function loginExists($login) {
            if ($settings::db_driver == 'xml') {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators as $administrator) {
                    if ($administrator->login == $login) {
                        return TRUE;
                    }
                }
                return FALSE;
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT COUNT(*) FROM ".$settings::db_prefix."administrators WHERE login = :login";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->execute();
                $count = $sth->fetchColumn();
                $sth = NULL;
                $dbh = NULL;

                if ($count > 0)
                    return TRUE;
                return FALSE;
            }
        }

        function getName($login) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == 'xml') {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators as $administrator) {
                    if ($administrator->login == $login) {
                        return $administrator->name;
                    }
                }
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT * FROM ".$settings::db_prefix."administrators WHERE login = :login";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->execute();
                $row = $sth->fetch();
                $sth = NULL;
                $dbh = NULL;
                return $row['name'];
            }
            return "";
        }

        function getEmail($login) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == 'xml') {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators as $administrator) {
                    if ($administrator->login == $login) {
                        return $administrator->email;
                    }
                }
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT * FROM ".$settings::db_prefix."administrators WHERE login = :login";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->execute();
                $row = $sth->fetch();
                $sth = NULL;
                $dbh = NULL;
                return $row['email'];
            }
            return "";
        }

        // Change administrator settings.
        ////////////////////////////////////

        // Change the name associated to an existing administrator in the file administrators.xml.
        function changeName($login, $name) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators->xpath("administrator[login='".$login."']") as $administrator) {
                    $administrator->name = $name;
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml", $administrators->asXML());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "UPDATE ".$settings::db_prefix."administrators SET name = :name WHERE login = :login";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 100);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        // Change the name associated to an existing administrator in the file administrators.xml.
        function changeEmail($login, $email) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == 'xml') {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators->xpath("administrator[login='".$login."']") as $administrator) {
                    $administrator->email = $email;
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml", $administrators->asXML());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "UPDATE ".$settings::db_prefix."administrators SET email = :email WHERE login = :login";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':email', $email, PDO::PARAM_STR, 75);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        // Change a password stored for an existing administrator in the file administrators.xml.
        function changePassword($login, $password) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators->xpath("administrator[login='".$login."']") as $administrator) {
                    $administrator->password = $password;
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml", $administrators->asXML());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "UPDATE ".$settings::db_prefix."administrators SET password = :password WHERE login = :login";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':password', $password, PDO::PARAM_STR, 255);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        // Token related code.
        /////////////////////////

        // Process password reset request.
        function setToken($login) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
            $common = new common();

            // Create a new token and make sure it is unique.
            $token = $common->randomString(10);
            $goodToken = FALSE;
            while (!$goodToken) {
                $goodToken = TRUE;
                if ($settings::db_driver == "xml") {
                    // XML
                    $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                    foreach ($administrators->xpath("administrator[login='".$login."']") as $administrator) {
                        if ($administrator->token == $token)
                            $goodToken = FALSE;
                    }
                } else {
                    $dbh = $common->pdoOpen();
                    $sql = "SELECT COUNT(*) FROM ".$settings::db_prefix."administrators WHERE token = :token";
                    $sth = $dbh->prepare($sql);
                    $sth->bindParam(':token', $token, PDO::PARAM_STR, 10);
                    $sth->execute();
                    $count = $sth->fetchColumn();
                    $sth = NULL;
                    $dbh = NULL;

                    if ($count > 0)
                        $goodToken = FALSE;
                }
            }

            // Assign this token to the administrator.
            if ($settings::db_driver == "xml") {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators->xpath("administrator[login='".$login."']") as $administrator) {
                    $administrator->token = $token;
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml", $administrators->asXML());
            } else {
                // PDO
                $dbh = $common->pdoOpen();
                $sql = "UPDATE ".$settings::db_prefix."administrators SET token = :token WHERE login = :login";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':token', $token, PDO::PARAM_STR, 10);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
            return $token;
        }

        // Geta login using a token.
        function getLoginUsingToken($token) {
            if ($settings::db_driver == "xml") {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators as $administrator) {
                    if ($administrator->token == $token) {
                        return $administrator->login;
                    }
                }
                return NULL;
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT * FROM ".$settings::db_prefix."administrators WHERE token = :token";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':token', $token, PDO::PARAM_STR, 10);
                $sth->execute();
                $row = $sth->fetch();
                $sth = NULL;
                $dbh = NULL;
                return $row['login'];
            }
        }
    }
?>
