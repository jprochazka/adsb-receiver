{*

    ////////////////////////////////////////////////////////////////////////////////
    //                 ADS-B RECEIVER PORTAL TEMPLATE INFORMATION                 //
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
    // Copyright (c) 2015-2016 Joseph A. Prochazka                                //
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
        <link rel="stylesheet" href="/templates/{setting:template}/assets/css/bootstrap.min.css">
        <link rel="stylesheet" href="/templates/{setting:template}/assets/css/bootstrap-theme.min.css">
        <link rel="stylesheet" href="/templates/{setting:template}/assets/css/portal.css">
        {if setting:enableWebNotifications eq TRUE}<link rel="stylesheet" href="/templates/{setting:template}/assets/css/notifications.css">{/if}
        {area:head}
    </head>
        <body>
        <div id="wrapper">
            <nav id="navbar" class="navbar navbar-default navbar-fixed-top" role="navigation">
                <div class="container">
                    <div class="navbar-header">
                        <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
                            <span class="sr-only">Toggle navigation</span>
                            <span class="icon-bar"></span>
                            <span class="icon-bar"></span>
                            <span class="icon-bar"></span>
                        </button>
                        <a class="navbar-brand" href="/">{setting:siteName}</a>
                    </div>
                    <div class="navbar-collapse collapse">
                        <ul class="nav navbar-nav">
                            {if setting:enableBlog eq TRUE}<li id="blog-link"><a href="/blog.php">Blog</a></li>{/if}
                            {if setting:enableAcars eq TRUE}<li id="acars-link"><a href="/acars.php">ACARS</a></li>{/if}
                            {if setting:enableFlights eq TRUE}<li id="flights-link"><a href="/flights.php">Flights</a></li>{/if}
                            <li class="dropdown">
                                <a href="#" class="dropdown-toggle" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false">System <span class="caret"></span></a>
                                <ul class="dropdown-menu">
                                    {if setting:enableGraphs eq TRUE}<li id="graphs-link"><a href="/graphs.php">Performance Graphs</a></li>{/if}
                                    {if setting:enableInfo eq TRUE}<li id="system-link"><a href="/system.php">System Information</a></li>{/if}
                                </ul>
                            </li>
                            <li class="dropdown">
                                <a href="#" class="dropdown-toggle" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false">Maps <span class="caret"></span></a>
                                <ul class="dropdown-menu">
                                    {if setting:enableDump1090 eq TRUE}<li id="dump1090-link"><a href="/dump1090.php">Live Dump1090 Map</a></li>{/if}
                                    {if setting:enableDump978 eq TRUE}<li id="dump978-link"><a href="/dump978.php">Live Dump978 Map</a></li>{/if}
                                    {if setting:enablePfclient eq TRUE}<li id="planefinder-link"><a href="{page:baseurl}:30053" target="_blank">Plane Finder Client</a></li>{/if}
                                </ul>
                            </li>
                            {if setting:enableLinks eq TRUE}
                            <li class="dropdown">
                                <a href="#" class="dropdown-toggle" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false">Links <span class="caret"></span></a>
                                <ul class="dropdown-menu">
                                    {foreach page:links as link}<li><a href="{link->address}">{link->name}</a></li>{/foreach}
                                </ul>
                            </li>
                            {/if}
                        </ul>
                        {if setting:dataStorage neq xml}
                        <form name="search" method="post" action="flights.php" class="navbar-form navbar-right">
                            <div class="form-group">
                                <input type="text" name="flight" placeholder="Flight" class="form-control">
                            </div>
                            <button type="submit" class="btn btn-success">Search</button>
                        </form>
                        {/if}
                    </div>
                </div>
            </nav>
            {if setting:enableWebNotifications eq TRUE}
            <div id="flight-notifications" class="modal fade" tabindex="-1" role="dialog">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title">Flight Spotted</h4>
                        </div>
                        <div class="modal-body">
                            <p>This receiver is currently receiving data from the following flight number(s).</p>
                            <ul></ul>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>
            {/if}
            {area:contents}
            <div id="push"></div>
        </div>
        <footer id="footer">
            <div class="container">
                <p class="muted credits">
                    <a href="https://www.adsbreceiver.net">The ADS-B Receiver Project</a>
                </p>
            </div>
        </footer>
        <script src="/templates/{setting:template}/assets/js/jquery-3.1.1.min.js"></script>
        <script src="/templates/{setting:template}/assets/js/bootstrap.min.js"></script>
        {if setting:enableWebNotifications eq TRUE}
        <script src="/templates/{setting:template}/assets/js/notifications.js"></script>
        {/if}
        <script type="text/javascript">
            $('#{template:pageId}').addClass("active");
            {if setting:hideNavbarAndFooter eq TRUE}
            setTimeout(hideNavbar, 10000);
                setTimeout(hideFooter, 10000);
                function hideFooter(){
                    if ( $("#iframe-wrapper").length ) {
                        $('#iframe-wrapper').css('bottom', '0px');
                    }
                };

                $('#navbar').mouseenter(function() {
                    $('#navbar').fadeTo(600, 1.0, function(){
                        $('#iframe-wrapper').css('top', '50px');
                    });
                });

                $('#navbar').mouseleave(function() {
                    setTimeout(hideNavbar, 3000);
                });

                function hideNavbar(){
                    if ( $("#iframe-wrapper").length ) {
                        $('#navbar').fadeTo(400, 0.05, function(){
                        $('#iframe-wrapper').css('top', '0px');
                    });
                }
            };
            {/if}
        </script>
        {area:scripts}
   </body>
</html>

