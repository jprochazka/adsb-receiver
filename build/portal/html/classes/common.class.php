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

    class common {

        // PDO Database Access
        /////////////////////////

        // Open a connection to the database.
        function pdoOpen() {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            switch($settings::db_driver) {
                case 'mysql':
                    $dsn = "mysql:host=".$settings::db_host.";dbname=".$settings::db_database;
                    break;
                case 'sqlsrv':
                    $dsn = "sqlsrv:server=".$settings::db_host.";database=".$settings::db_database;
                    break;
                case 'pgsql':
                    $dsn = "pgsql:host=".$settings::db_host.";dbname=".$settings::db_database;
                    break;
                case 'sqlite':
                    // In v2.5.0 the path to the SQLite database is no longer hard coded.
                    // So if there is a problem getting the path the the SQLite database
                    // from settings.class.php we must use the old style hard coded path.
                    $dsn = "sqlite:".$settings::db_host;
                    if ($dsn == "sqlite:") {
                        // Use the legacy hard coded path for older systems being updated before v2.5.0.
                        $dsn = "sqlite:".$_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."portal.sqlite";
                    }
                    break;
            }

            $dbh = new PDO($dsn, $settings::db_username, $settings::db_password);
            if ($settings::db_driver == 'sqlite')
                $dbh = new PDO($dsn);
            if ($settings::pdo_debug == TRUE)
                $dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            return $dbh;
        }

        // Data Access
        /////////////////

        // Returns the value for the specified setting name.
        function getSetting($name) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($name == "dataStorage") {
                return $settings::db_driver;
            }

            if ($settings::db_driver == 'xml') {
                // XML
                $theseSettings = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."settings.xml");
                foreach ($theseSettings as $setting) {
                    if ($setting->name == $name) {
                        return $setting->value;
                    }
                }
            } else {
                // PDO
                $dbh = $this->pdoOpen();
                $sql = "SELECT * FROM ".$settings::db_prefix."settings WHERE name = :name";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 50);
                $sth->execute();
                $row = $sth->fetch();
                $sth = NULL;
                $dbh = NULL;
                return $row['value'];
            }
            return "";
        }

        // Updates the value for the specified setting name.
        function updateSetting($name, $value) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $settings = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."settings.xml");
                foreach ($settings->xpath("setting[name='".$name."']") as $setting) {
                    $setting->value = $value;
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."settings.xml", $settings->asXML());
            } else {
                // PDO
                $dbh = $this->pdoOpen();
                $sql = "UPDATE ".$settings::db_prefix."settings SET value = :value WHERE name = :name";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 50);
                $sth->bindParam(':value', $value, PDO::PARAM_STR, 100);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        function addSetting($name, $value) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $xmlSettings = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."settings.xml");
                $xmlSetting = $xmlSettings->addChild('setting');
                $xmlSetting->addChild('name', $name);
                $xmlSetting->addChild('value', $value);
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."settings.xml", $xmlSettings->asXML());
            } else {
                // PDO
                $dbh = $this->pdoOpen();
                $sql = "INSERT INTO ".$settings::db_prefix."settings (name, value) VALUES (:name, :value)";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 50);
                $sth->bindParam(':value', $value, PDO::PARAM_STR, 100);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        function deleteSetting($name) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                $xmlSettings = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."settings.xml");
                foreach($xmlSettings as $xmlSetting) {
                    if($xmlSetting->name == $name) {
                        $dom = dom_import_simplexml($xmlSetting);
                        $dom->parentNode->removeChild($dom);
                    }
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."settings.xml", $xmlSettings->asXml());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "DELETE FROM ".$settings::db_prefix."settings WHERE name = :name";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 100);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        // Returns the name associated to the specified administrator login.
        function getAdminstratorName($login) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $administrators = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."administrators.xml");
                foreach ($administrators as $administrator) {
                    if ($administrator->login = $login) {
                        return $administrator->name;
                    }
                }
            } else {
                // PDO
                $dbh = $this->pdoOpen();
                $sql = "SELECT * FROM ".$settings::db_prefix."administrators WHERE login = :login";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':login', $login, PDO::PARAM_STR, 25);
                $sth->execute();
                $row = $sth->fetch();
                $sth = NULL;
                $dbh = NULL;
                return $row['name'];
            }
        }

        // Functions Not Related To Data Retrieval
        /////////////////////////////////////////////

        // Check if page load is a post back.
        function postBack() {
            if ($_SERVER['REQUEST_METHOD'] === 'POST') {
                return TRUE;
            }
            return FALSE;
        }

        // Return a boolean from a string.
        function stringToBoolean($value) {
            switch(strtoupper($value)) {
                case 'TRUE': return TRUE;
                case 'FALSE': return FALSE;
                default: return NULL;
            }
        }

        // Generate a random string of the given length.
        function randomString($length) {
            $characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
            $string = '';
            for ($p = 0; $p < $length; $p++) {
                 $string .= $characters[mt_rand(0, strlen($characters))];
            }
            return $string;
        }

        // Returns the supplied file name without an extension.
        function removeExtension($fileName) {
            return pathinfo($fileName, PATHINFO_FILENAME);
        }

        // Remove all HTML tags from a string.
        function removeHtmlTags($string) {
            $string = preg_replace ('/<[^>]*>/', ' ', $string); 
            $string = str_replace("\r", '', $string);
            $string = str_replace("\n", ' ', $string);
            $string = str_replace("\t", ' ', $string);
            $string = trim(preg_replace('/ {2,}/', ' ', $string));
            return $string; 
        }

        // Remove HTML from a string and shorten to the specified length.
        function cleanAndShortenString($string, $length) {
            return substr($this->removeHtmlTags($string), 0, $length);
        }

        // Pagination.
        function paginateArray($inArray, $page, $itemsPerPage) {
            $page = $page < 1 ? 1 : $page;
            $start = ($page - 1) * ($itemsPerPage + 1);
            $offset = $itemsPerPage + 1;
            return array_slice($inArray, $start, $offset);
        }

        // Function that returns the string contained between two strings.
        function extractString($string, $start, $end) {
            $string = " ".$string;
            $ini = strpos($string, $start);
            if ($ini == 0) return "";
            $ini += strlen($start);
            $len = strpos($string, $end, $ini) - $ini;
            return substr($string, $ini, $len);
        }

        // Returns the base URL from the requested URL.
        function getBaseUrl(){
            if(isset($_SERVER['HTTPS'])){
                $protocol = ($_SERVER['HTTPS'] && $_SERVER['HTTPS'] != "off") ? "https" : "http";
            } else {
                $protocol = 'http';
            }
            return $protocol."://".$_SERVER['HTTP_HOST'];
        }

        // Send an email.
        function sendEmail($to, $subject, $message) {
            $headers = 'From: '.$this->getSetting("emailFrom")."\r\n".
                       'Reply-To: '.$this->getSetting("emailReplyTo")."\r\n".
                       'X-Mailer: PHP/'.phpversion();
            return mail($to, $subject, $message, $headers);
        }

        // Get the size of the database.
        function getDatabaseSize($measurement = "") {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();
            
            if ($settings::db_driver == "sqlite") {
                $databaseSize = filesize($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."portal.sqlite");
            } elseif ($settings::db_driver == "mysql") {
                $dbh = $this->pdoOpen();
                $sql = "SHOW TABLE STATUS";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $databaseSize = $sth->fetch(PDO::FETCH_ASSOC)["Data_length"];
                $sth = NULL;
                $dbh = NULL;
            } else {
                $databaseSize = 0;
            }
            switch ($measurement) {
                case "kb":
                    return round($databaseSize / 1024, 2);
                    break;
                case "mb":
                    return round($databaseSize / 1024 / 1024, 2);
                    break;
                case "gb":
                    return round($databaseSize / 1024 / 1024 /1024, 2);
                    break;
                case "tb":
                    return round($databaseSize / 1024 /1024 /1024 /1024, 2);
                    break;
                default:
                    return $databaseSize;
            }
        }
    }
?>
