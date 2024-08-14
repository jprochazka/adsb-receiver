{area:head/}
{area:contents}
            <div class="container">
                <h1>Flights Seen</h1>
                <hr />
                <table class="table table-striped">
                    <tr>
                        <th>Flight</th>
                        <th>Last Seen</th>
                        <th>First Seen</th>
                        <th>Links</th>
                    </tr>
                    {foreach page:flights as flight}
                    <tr>
                        <td><a href="plot.php?flight={flight->flight}">{flight->flight}</a></td>
                        <td><a href="plot.php?flight={flight->flight}&index=last">{flight->lastSeen}</a></td>
                        <td><a href="plot.php?flight={flight->flight}&index=first">{flight->firstSeen}</a></td>
                        <td>
                            <a href="http://flightaware.com/live/flight/{flight->flight}" target="_blank">FlightAware</a> |
                            <a href="https://planefinder.net/flight/{flight->flight}" target="_blank">Planefinder</a> |
                            <a href="https://www.flightradar24.com/data/flights/{flight->flight}" target="_blank">Flightradar24</a>
                        </td>
                    {/foreach}
                </table>
                <p id="page-nav"></p>
            </div>
{/area}
{area:scripts}
<script src="/templates/{setting:template}/assets/js/jquery.bootpag.min.js"></script>
        <script>
            $('#page-nav').bootpag({
                total: {page:pageLinks},
                page: {page:pageNumber},
                maxVisible: 10,
                leaps: true,
                firstLastUse: true,
                first: '<',
                last: '>',
                wrapClass: 'pagination',
                activeClass: 'active',
                disabledClass: 'disabled',
                nextClass: 'next',
                prevClass: 'prev',
                lastClass: 'last',
                firstClass: 'first'
            }).on("page", function(event, num){
                window.location="/flights.php?page=" + num;
            });
        </script>
{/area}
