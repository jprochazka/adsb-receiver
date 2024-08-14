<?php
    class blog {

        function getAllPosts($orderBy = "desc") {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $posts = array();
                $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml");
                foreach ($blogPosts as $blogPost) {
                    $posts[] = array("title"=>$blogPost->title, "date"=>$blogPost->date, "author"=>$blogPost->author, "contents"=>$blogPost->contents);
                }
                // Sort the results by date either desc or asc.
                if(strtolower($orderBy) == "desc") {
                    usort($posts, function($a, $b) {
                        return strtotime($b["date"]) - strtotime($a["date"]);
                    });
                } else {
                    usort($posts, function($a, $b) {
                        return strtotime($a["date"]) - strtotime($b["date"]);
                    });
                }
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT * FROM ".$settings::db_prefix."blogPosts ORDER BY date ".$orderBy;
                $sth = $dbh->prepare($sql);
                $sth->execute();
                $posts = $sth->fetchAll(PDO::FETCH_ASSOC);
                $sth = NULL;
                $dbh = NULL;
                return $posts;
            }
            return $posts;
        }

        function getPostByTitle($title) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml");
                foreach ($blogPosts as $blogPost) {
                    if (strtolower($blogPost->title) == strtolower($title)) {
                        return (array)$blogPost;
                    }
                }
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT * FROM ".$settings::db_prefix."blogPosts WHERE title = :title";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':title', $title, PDO::PARAM_STR, 100);
                $sth->execute();
                $blogPost = $sth->fetch(PDO::FETCH_ASSOC);
                $sth = NULL;
                $dbh = NULL;
                return $blogPost;
            }
        }

        function titleExists($newTitle) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml");
                foreach ($blogPosts as $blogPost) {
                    if ($blogPost->title == $newTitle) {
                        return TRUE;
                    }
                }
                return FALSE;
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "SELECT COUNT(*) FROM ".$settings::db_prefix."blogPosts WHERE title = :title";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':title', $title, PDO::PARAM_STR, 100);
                $sth->execute();
                $count = $sth->fetchColumn();
                $sth = NULL;
                $dbh = NULL;

                if ($count > 0)
                    return TRUE;
                return FALSE;
            }
        }

        function editContentsByTitle($originalTitle, $contents) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml");
                foreach ($blogPosts->xpath("blogPost[title='".$originalTitle."']") as $blogPost) {
                    $blogPost->contents = html_entity_decode($contents, null, "UTF-8");
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml", $blogPosts->asXML());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "UPDATE ".$settings::db_prefix."blogPosts SET contents = :contents WHERE title = :title";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':title', $originalTitle, PDO::PARAM_STR, 100);
                $sth->bindParam(':contents', $contents, PDO::PARAM_STR, 20000);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        function deletePostByTitle($title) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml");
                foreach($blogPosts as $blogPost) {
                    if($blogPost->title == $title) {
                        $dom = dom_import_simplexml($blogPost);
                        $dom->parentNode->removeChild($dom);
                    }
                }
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml", $blogPosts->asXml());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "DELETE FROM ".$settings::db_prefix."blogPosts WHERE title = :title";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':title', $title, PDO::PARAM_STR, 100);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }

        function addPost($author, $title, $contents) {
            require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
            $settings = new settings();

            if ($settings::db_driver == "xml") {
                // XML
                $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml");
                $blogPost = $blogPosts->addChild('blogPost', '');
                $blogPost->addChild('title', $title);
                $blogPost->addChild('date', gmdate('Y-m-d H:i:s', time()));
                $blogPost->addChild('author', $author);
                $blogPost->addChild('contents', html_entity_decode($contents, null, "UTF-8"));
                $dom = dom_import_simplexml($blogPosts)->ownerDocument;
                $dom->formatOutput = TRUE;
                file_put_contents($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml", $dom->saveXML());
            } else {
                // PDO
                require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
                $common = new common();

                $dbh = $common->pdoOpen();
                $sql = "INSERT INTO ".$settings::db_prefix."blogPosts (title, date, author, contents) VALUES (:title, :date, :author, :contents)";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':title', $title, PDO::PARAM_STR, 100);
                $sth->bindParam(':date', gmdate('Y-m-d H:i:s', time()), PDO::PARAM_STR, 20);
                $sth->bindParam(':author', $author, PDO::PARAM_STR, 100);
                $sth->bindParam(':contents', $contents, PDO::PARAM_STR, 20000);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }
    }
?>
