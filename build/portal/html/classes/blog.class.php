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

    class blog {

        function getTitlesAndDates($orderBy = "desc") {
            // Get all posts from the blogposts.xml file.
            $posts = array();
            $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/blogPosts.xml") or die("Error: Cannot create blogPosts object");
            foreach ($blogPosts as $blogPost) {
                $posts[] = array("title"=>$blogPost->title, "date"=>$blogPost->date);
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
            return $posts;
        }

        function getAllPosts($orderBy = "desc") {
            // Get all posts from the blogposts.xml file.
            $posts = array();
            $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/blogPosts.xml") or die("Error: Cannot create blogPosts object");
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
            return $posts;
        }

        function getPostByTitle($title) {
            $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/blogPosts.xml") or die("Error: Cannot create blogPosts object");
            foreach ($blogPosts as $blogPost) {
                if (strtolower($blogPost->title) == $title) {
                    return $blogPost;
                }
            }
        }

        function editContentsByTitle($title, $contents) {
            $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/blogPosts.xml") or die("Error: Cannot create blogPosts object");
            foreach ($blogPosts->xpath("blogPost[title='".$title."']") as $blogPost) {
                $blogPost->contents = $contents;
            }
            file_put_contents($_SERVER['DOCUMENT_ROOT']."/data/blogPosts.xml", $blogPosts->asXML());
        }

        function deletePostByTitle($title) {
            $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/blogPosts.xml") or die("Error: Cannot create blogPosts object");
            foreach($blogPosts as $blogPost) {
                if($blogPost->title == $title) {
                    $dom = dom_import_simplexml($blogPost);
                    $dom->parentNode->removeChild($dom);
                }
            }
            file_put_contents($_SERVER['DOCUMENT_ROOT']."/data/blogPosts.xml", $blogPosts->asXml());
        }

        function addPost($author, $title, $contents) {
            $blogPosts = simplexml_load_file($_SERVER['DOCUMENT_ROOT']."/data/blogPosts.xml") or die("Error: Cannot create blogPosts object");
            $blogPost = $blogPosts->addChild('blogPost', '');
            $blogPost->addChild('title', $title);
            $blogPost->addChild('date', date('Y-m-d H:i:s'));
            $blogPost->addChild('author', $author);
            $blogPost->addChild('contents', $contents);
            $dom = dom_import_simplexml($blogPosts)->ownerDocument;
            $dom->formatOutput = TRUE;
            file_put_contents($_SERVER['DOCUMENT_ROOT']."/data/blogPosts.xml", $dom->saveXML());
        }
    }
?>