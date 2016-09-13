{*

    ////////////////////////////////////////////////////////////////////////////////
    //                 ADS-B RECEIVER PORTAL TEMPLATE INFORMATION                 //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: dump978.tpl                                                 //
    // Version: 2.0.0                                                             //
    // Release Date:                                                              //
    // Author: Joe Prochazka                                                      //
    // Website: https://www.swiftbyte.com                                         //
    // ========================================================================== //
    // Copyright and Licensing Information:                                       //
    //                                                                            //
    // Copyright (c) 2015-2016 Joseph A. Prochazka                                //
    //                                                                            //
    // This template set is licensed under The MIT License (MIT)                  //
    // A copy of the license can be found package along with these files.         //
    ////////////////////////////////////////////////////////////////////////////////

*}


{area:head}
        <link rel="stylesheet" href="templates/{setting:template}/assets/css/logs.css">
{/area}
{area:contents}
            <div id="iframe-wrapper">
              <iframe id="logs" src="{page:baseurl}:9001"></iframe>
            </div>
{/area}
{area:scripts/}
