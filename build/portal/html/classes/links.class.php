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

    class links {

        function getAllLinks() {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $links = array();
                $xmlLinks = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml");
                foreach ($xmlLinks as $xmlLink) {
                    $links[] = array("name"=>$xmlLink->name, "address"=>$xmlLink->address);
                }
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT name, address FROM ".$settings::db_prefix."links ORDER BY name";
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $links = $sth->fetchAll(PDO::FETCH_ASSOC);
                $sth = NULL;
                $dbh = NULL;
            }
            return $links;
        }

        function getLinkByName($name) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $links = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml");
                foreach ($links as $link) {
                    if (strtolower($link->name) == strtolower($name)) {
                        return (array)$link;
                    }
                }
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT * FROM ".$settings::db_prefix."links WHERE name = :name";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 100);
                $sth->execute();
                $link = $sth->fetch(PDO::FETCH_ASSOC);
                $sth = NULL;
                $dbh = NULL;
                return $link;
            }
        }

        function nameExists($newName) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $links = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml");
                foreach ($links as $link) {
                    if ($link->name == $name) {
                        return TRUE;
                    }
                }
                return FALSE;
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT COUNT(*) FROM ".$settings::db_prefix."links WHERE name = :name";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 100);
                $sth->execute();
                $count = $sth->fetchColumn();
                $sth = NULL;
                $dbh = NULL;

                if ($count > 0)
                    return TRUE;
                return FALSE;
            }
        }

        function addLink($name, $address) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $links = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml");
                $link = $blogPosts->addChild('blogPost', '');
                $link->addChild('name', $title);
                $link->addChild('address', $address);
                $dom = dom_import_simplexml($links)->ownerDocument;
                $dom->formatOutput = TRUE;
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml", $dom->saveXML());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "INSERT INTO ".$settings::db_prefix."links (name, address) VALUES (:name, :address)";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 100);
                $sth->bindParam(':address', $address, PDO::PARAM_STR, 250);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        function editLinkByName($originalName, $name, $address) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $links = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml");
                foreach ($links->xpath("link[name='".$originalName."']") as $link) {
                    $link->name = $name;
                    $link->address = $address;
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml", $links->asXML());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "UPDATE ".$settings::db_prefix."links SET name = :name, address = :address WHERE name = :originalName";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':originalName', $originalName, PDO::PARAM_STR, 100);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 100);
                $sth->bindParam(':address', $address, PDO::PARAM_STR, 250);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        function deleteLinkByName($name) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml");
                foreach($linkss as $link) {
                    if($link->name == $name) {
                        $dom = dom_import_simplexml($link);
                        $dom->parentNode->removeChild($dom);
                    }
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml", $blogPosts->asXml());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "DELETE FROM ".$settings::db_prefix."links WHERE name = :name";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':name', $name, PDO::PARAM_STR, 100);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }
    }
?>
