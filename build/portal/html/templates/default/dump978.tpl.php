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

    // The title of this page.
    $pageTitle = "Live Dump978 Map";

    ////////////////////////////////
    // Additional <head> content.
    function headContent() {
?>
        <link rel="stylesheet" href="assets/css/dump978.css">
<?php
    }

    ///////////////////
    // Page content.
    function pageContent() {
?>
            <div id="iframe-wrapper">
                <iframe id="map" src="/dump978/gmap.html"></iframe>
            </div>
<?php
    }

    /////////////////////////////////////////////////
    // Content to be added to the scripts section.
    function scriptContent() {}
?>