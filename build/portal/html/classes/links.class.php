<?php
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
                $link = $links->addChild('link', '');
                $link->addChild('name', $name);
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
                $links = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml");
                foreach($links as $link) {
                    if($link->name == $name) {
                        $dom = dom_import_simplexml($link);
                        $dom->parentNode->removeChild($dom);
                    }
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."links.xml", $links->asXml());
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
