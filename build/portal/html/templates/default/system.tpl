{*

    ////////////////////////////////////////////////////////////////////////////////
    //                 ADS-B RECEIVER PORTAL TEMPLATE INFORMATION                 //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: system.tpl                                                  //
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
{area:head/}
{area:contents}
            <div class="container">
                <h1>System Information</h1>
                <h2>Aggregate Sites Statistics</h2>
                <ul>
                    {if setting:enableFlightAwareLink eq TRUE}<li><a href="{page:flightAwareLink}">FlightAware Stats</a></li>{/if}
                    {if setting:enablePlaneFinderLink eq TRUE}<li><a href="{page:planeFinderLink}">Planfinder Stats</a></li>{/if}
                    {if setting:enableFlightRadar24Link eq TRUE}<li><a href="{page:flightRader24Link}">Flightradar24 Stats</a></li>{/if}
                    {if setting:enableAdsbExchangeLink eq TRUE}<li><a href="{page:adsbExchangeLink}">ADS-B Exchange</a></li>{/if}
                </ul>
                <h2>System Charts</h2>
                <div id="chart_div" style="width: 400px; height: 120px;"></div>
                <h2>System Information</h2>
                <ul>
                    <li>Uptime: </li>
                </ul>
            </div>
{/area}
{area:scripts}
        <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
        <script src="/templates/{setting:template}/assets/js/system.js"></script>
{/area}