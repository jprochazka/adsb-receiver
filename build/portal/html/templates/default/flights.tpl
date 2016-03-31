{*

    ////////////////////////////////////////////////////////////////////////////////
    //                 ADS-B RECEIVER PORTAL TEMPLATE INFORMATION                 //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: blog.tpl                                                    //
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
                <h1>Flights Seen</h1>
                <hr />
                <table class="table table-striped">
                    <tr>
                        <th>Flight</th>
                        <th>Last Seen</th>
                        <th>Links</th>
                    </tr>
                    {foreach page:flights as flight}
                    <tr>
                        <td><a href="plot.php?flight={flight->flight}">{flight->flight}</a></td>
                        <td>{flight->lastSeen}</td>
                        <td>
                            <a href="http://flightaware.com/live/flight/{flight->flight}" target="_blank">FlightAware</a> |
                            <a href="https://planefinder.net/flight/{flight->flight}" target="_blank">Planefinder</a> |
                            <a href="https://www.flightradar24.com/data/flights/{flight->flight}" target="_blank">Flightradar24</a>
                        </td>
                    {/foreach}
                </table>
                <ul class="pagination">
                    {for pageNumber eq 1 to page:pageLinks}
                    <li><a href="flights.php?page={pageNumber}">{pageNumber}</a></li>
                    {/for}
                </ul>
            </div>
{/area}
{area:scripts/}

