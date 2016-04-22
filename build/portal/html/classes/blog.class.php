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
                $posts = $sth->fetchAll();
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
                $blogPost = $sth->fetch();
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
                "SELECT COUNT(*) FROM ".$settings::db_prefix."blogPosts WHERE title = :title";
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

                // Since &nbsp; is not defined as an XML entity we need to replace it with it's numeric character reference &#160;.
                $contents = str_replace("&nbsp;", "&#160;", $contents);

                $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml");
                foreach ($blogPosts->xpath("blogPost[title='".$originalTitle."']") as $blogPost) {
                    $blogPost->contents = $contents;
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

                // Since &nbsp; is not defined as an XML entity we need to replace it with it's numeric character reference &#160;.
                $contents = str_replace("&nbsp;", "&#160;", $contents);

                $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."data".DIRECTORY_SEPARATOR."blogPosts.xml");
                $blogPost = $blogPosts->addChild('blogPost', '');
                $blogPost->addChild('title', $title);
                $blogPost->addChild('date', date('Y-m-d H:i:s'));
                $blogPost->addChild('author', $author);
                $blogPost->addChild('contents', $contents);
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
                $sth->bindParam(':date', date('Y-m-d H:i:s'), PDO::PARAM_STR, 20);
                $sth->bindParam(':author', $author, PDO::PARAM_STR, 100);
                $sth->bindParam(':contents', $contents, PDO::PARAM_STR, 20000);
                $sth->execute();
                $sth = NULL;
                $dbh = NULL;
            }
        }
    }
?>
