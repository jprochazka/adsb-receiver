<?php

    ////////////////////////////////////////////////////////////////////////////////
    //                  ADS-B FEEDER PORTAL TEMPLATE INFORMATION                  //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: master                                                      //
    // Version: 1.0.0                                                             //
    // Release Date:                                                              //
    // Author: Joe Prochazka                                                      //
    // Website: https://www.swiftbyte.com                                         //
    // ========================================================================== //
    // Copyright and Licensing Information:                                       //
    //                                                                            //
    // Copyright (c) 2015 Joseph A. Prochazka                                     //
    //                                                                            //
    // This template set is licensed under The MIT License (MIT)                  //
    // A copy of the license can be found package along with these files.         //
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////
    // Additional <head> content.
    function headContent() { }

    ///////////////////
    // Page content.
    function pageContent() {
        global $post;
?>
            <div class="container">
                <h1><?php echo $post->title; ?></h1>
                <p>Posted <strong><?php echo date_format(date_create($post->date), "F jS, Y"); ?></strong> by <strong><?php echo $post->author; ?></strong>.</p>
                <div><?php echo $post->contents; ?></div>
            </div>
<?php
    }

    /////////////////////////////////////////////////
    // Content to be added to the scripts section.
    function scriptContent() {}
?>