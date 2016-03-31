{*

    ////////////////////////////////////////////////////////////////////////////////
    //                 ADS-B RECEIVER PORTAL TEMPLATE INFORMATION                 //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: dump1090.tpl                                                //
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
        <link rel="stylesheet" href="templates/{setting:template}/assets/css/dump1090.css">
{/area}
{area:contents}
            <div id="iframe-wrapper">
                <div id="map"></div>
            </div>
{/area}
{area:scripts}
    <script>

      // This example creates a 2-pixel-wide red polyline showing the path of William
      // Kingsford Smith's first trans-Pacific flight between Oakland, CA, and
      // Brisbane, Australia.

      function initMap() {
        var map = new google.maps.Map(document.getElementById('map'), {
          zoom: 7,
          center: {lat: 41.379857, lng: -82.082877},
          mapTypeId: google.maps.MapTypeId.TERRAIN
        });

        var marker = new google.maps.Marker({
          position: {lat: {page:startingLatitude}, lng: {page:startingLongitude}},
          map: map
        });
        var marker = new google.maps.Marker({
          position: {lat: {page:finishingLatitude}, lng: {page:finishingLongitude}},
          map: map
        });

        var flightPlanCoordinates = [
            {foreach page:positions as position}
            {lat: {position->latitude}, lng: {position->longitude}},
            {/foreach}
        ];
        var flightPath = new google.maps.Polyline({
          path: flightPlanCoordinates,
          geodesic: true,
          strokeColor: '#FF0000',
          strokeOpacity: 1.0,
          strokeWeight: 2
        });

        flightPath.setMap(map);
      }
    </script>
    <script async defer src="https://maps.googleapis.com/maps/api/js?key=AIzaSyAibOqEH7XseMCHOPQUdBon6LHKSlbGHj4&callback=initMap"></script>
{/area}
