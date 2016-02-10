{*

    ////////////////////////////////////////////////////////////////////////////////
    //                  ADS-B FEEDER PORTAL TEMPLATE INFORMATION                  //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: master.tpl                                                  //
    // Version: 2.0.0                                                             //
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

*}
<!DOCTYPE html>
<html lang="en">
    <head>
    <meta charset="utf-8">
    <title>{setting:siteName}: {page:title}</title>
        <meta http-equiv="cache-control" content="no-cache" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css">
        <link rel="stylesheet" href="/templates/{setting:template}/assets/css/portal.css">
        {area:head}
    </head>
        <body>
        <div id="wrapper">
            <nav class="navbar navbar-default navbar-fixed-top" role="navigation">
                <div class="container">
                    <div class="navbar-header">
                        <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
                            <span class="sr-only">Toggle navigation</span>
                            <span class="icon-bar"></span>
                            <span class="icon-bar"></span>
                            <span class="icon-bar"></span>
                        </button>
                        <a class="navbar-brand" href="/">{setting:siteName}</title></a>
                    </div>
                    <div class="navbar-collapse collapse">
                        <ul class="nav navbar-nav">
                            {if setting:enableBlog eq TRUE}<li id="blog-link"><a href="/blog.php">Blog</a></li>{/if}
                            {if setting:enableInfo eq TRUE}<li id="system-link"><a href="/system.php">System Information</a></li>{/if}
                            {if setting:enableGraphs eq TRUE}<li id="graphs-link"><a href="/graphs.php">Performance Graphs</a></li>{/if}
                            {if setting:enableDump1090 eq TRUE}<li id="dump1090-link"><a href="/dump1090.php">Live Dump1090 Map</a></li>{/if}
                            {if setting:enableDump978 eq TRUE}<li id="dump978-link"><a href="/dump978.php">Live Dump978 Map</a></li>{/if}
                            {if setting:enablePfclient eq TRUE}<!-- Plane Finder ADS-B Client Link Placeholder -->{/if}
                        </ul>
                    </div>
                </div>
            </nav>
            {area:contents}
            <div id="push"></div>
        </div>
        <footer id="footer">
            <div class="container">
                <p class="muted credits">
                    <a href="https://github.com/jprochazka/adsb-feeder">The ADS-B Feeder Project</a>
                </p>
            </div>
        </footer>
        <script src="https://code.jquery.com/jquery-2.2.0.min.js"></script>
        <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
        <script type="text/javascript">
            $('#{template:pageId}').addClass("active");
        </script>
        {area:scripts}
   </body>
</html>
