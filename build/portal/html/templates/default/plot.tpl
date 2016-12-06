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
        <style>
            .sidebar.left {
                position: fixed;
                top: 49px;
                left: 0;
                bottom: 60px;
                width: 270px;
                background: #448AFF;
                z-index: 10000;
            }
            .sidebar {
                position: fixed;
                color: white;
                padding: 30px;
                font-size: 0.7em;
            }
        </style>
{/area}
{area:contents}
            {if page:flightPathsAvailable eq FALSE}
            <div class="modal fade in" id="no-data-modal" tabindex="-1" role="dialog" aria-labelledby="no-data-modal-label">
                <div class="modal-dialog" role="document">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                            <h4 class="modal-title" id="no-data-modal-label">No Position Data</h4>
                        </div>
                        <div class="modal-body">
                            <p>There is no position data for this flight.</p>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                 </div>
            </div>
            {/if}

            <div class="sidebar left">
                <h3>Flight Data</h3>
                <p>
                    <div><strong>ICAO: <span id="icao"></span></strong></div>
                    <div><strong>Flight Number: <span id="flight"></span></strong></div>
                </p>
                <p>
                    <div>Aircraft First Seen: <span id="afs"></span></div>
                    <div>Aircraft Last Seen: <span id="als"></span></div>
                </p>
                <p>
                    <div>Flight First Seen: <span id="ffs"></span></div>
                    <div>Flight Last Seen: <span id="fls"></span></div>
                </p>
            </div>

            <div id="iframe-wrapper">
                <div id="map"></div>
            </div>
{/area}
{area:scripts}
    {if page:flightPathsAvailable eq FALSE}
    <script type="text/javascript">
        $(window).load(function(){
            $('#no-data-modal').modal('show');
        });
    </script>
    {/if}

    <script src="/templates/{setting:template}/assets/js/jquery.sidebar.js"></script>
    <script>
        var thisPosition;

        function setPosition(position) {
            thisPosition = position;
        }

        $(document).ready(function () {
            $(".sidebar.left").sidebar({side: "left"});

            $(".sidebar.left").on("sidebar:opened", function () {
                // Gather data for this particular sighting from the database.
                $.ajax({
                    url: '/api/flight.php',
                    type: 'GET',
                    cache: false,
                    datatype: 'json',
                    data: {
                        type: 'byPosition',
                        position: thisPosition
                    },
                    success: function(json) {
                        var data = $.parseJSON(json);
                        $('#icao').text(data['icao']);
                        $('#flight').text(data['flight']);
                        $('#afs').text(data['afs']);
                        $('#als').text(data['als']);
                        $('#ffs').text(data['ffs']);
                        $('#fls').text(data['fls']);
                    },
                    error: function(response) {
                        console.log(response);
                    }
                });
            });
        });
    </script>

    <script src="/templates/{setting:template}/assets/js/date.format.js"></script>
    <script>
      var genericPlaneSvg = "M 0,0 " +
        "M 1.9565564,41.694305 C 1.7174505,40.497708 1.6419973,38.448747 " +
        "1.8096508,37.70494 1.8936398,37.332056 2.0796653,36.88191 2.222907,36.70461 " +
        "2.4497603,36.423844 4.087816,35.47248 14.917931,29.331528 l 12.434577," +
        "-7.050718 -0.04295,-7.613412 c -0.03657,-6.4844888 -0.01164,-7.7625804 " +
        "0.168134,-8.6194061 0.276129,-1.3160905 0.762276,-2.5869575 1.347875," +
        "-3.5235502 l 0.472298,-0.7553719 1.083746,-0.6085497 c 1.194146,-0.67053522 " +
        "1.399524,-0.71738842 2.146113,-0.48960552 1.077005,0.3285939 2.06344," +
        "1.41299352 2.797602,3.07543322 0.462378,1.0469993 0.978731,2.7738408 " +
        "1.047635,3.5036272 0.02421,0.2570284 0.06357,3.78334 0.08732,7.836246 0.02375," +
        "4.052905 0.0658,7.409251 0.09345,7.458546 0.02764,0.04929 5.600384,3.561772 " +
        "12.38386,7.805502 l 12.333598,7.715871 0.537584,0.959688 c 0.626485,1.118378 " +
        "0.651686,1.311286 0.459287,3.516442 -0.175469,2.011604 -0.608966,2.863924 " +
        "-1.590344,3.127136 -0.748529,0.200763 -1.293144,0.03637 -10.184829,-3.07436 " +
        "C 48.007733,41.72562 44.793806,40.60197 43.35084,40.098045 l -2.623567," +
        "-0.916227 -1.981212,-0.06614 c -1.089663,-0.03638 -1.985079,-0.05089 -1.989804," +
        "-0.03225 -0.0052,0.01863 -0.02396,2.421278 -0.04267,5.339183 -0.0395,6.147742 " +
        "-0.143635,7.215456 -0.862956,8.845475 l -0.300457,0.680872 2.91906,1.361455 " +
        "c 2.929379,1.366269 3.714195,1.835385 4.04589,2.41841 0.368292,0.647353 " +
        "0.594634,2.901439 0.395779,3.941627 -0.0705,0.368571 -0.106308,0.404853 " +
        "-0.765159,0.773916 L 41.4545,62.83158 39.259237,62.80426 c -6.030106,-0.07507 " +
        "-16.19508,-0.495041 -16.870991,-0.697033 -0.359409,-0.107405 -0.523792," +
        "-0.227482 -0.741884,-0.541926 -0.250591,-0.361297 -0.28386,-0.522402 -0.315075," +
        "-1.52589 -0.06327,-2.03378 0.23288,-3.033615 1.077963,-3.639283 0.307525," +
        "-0.2204 4.818478,-2.133627 6.017853,-2.552345 0.247872,-0.08654 0.247455," +
        "-0.102501 -0.01855,-0.711959 -0.330395,-0.756986 -0.708622,-2.221756 -0.832676," +
        "-3.224748 -0.05031,-0.406952 -0.133825,-3.078805 -0.185533,-5.937448 -0.0517," +
        "-2.858644 -0.145909,-5.208974 -0.209316,-5.222958 -0.06341,-0.01399 -0.974464," +
        "-0.0493 -2.024551,-0.07845 L 23.247235,38.61921 18.831373,39.8906 C 4.9432155," +
        "43.88916 4.2929558,44.057819 3.4954426,43.86823 2.7487826,43.690732 2.2007966," +
        "42.916622 1.9565564,41.694305 z";

      function initMap() {
        var map = new google.maps.Map(document.getElementById('map'), {
          zoom: 7,
          center: {lat: 41.379857, lng: -82.082877},
          mapTypeId: google.maps.MapTypeId.TERRAIN
        });

        var pathsSeen = {page:pathsSeen};

        {foreach page:flightPaths as flightPath}
        var startTime{flightPath->id} = dateFormat("{flightPath->startingTime}", "mmmm dd, yyyy 'at' h:MM TT");

        var contentStringStart{flightPath->id} = '' +
            '<h4>Sighting Number {flightPath->id}</h4>' +
            '<p><strong>First Sighting</strong></p>' +
            '<p>' +
            '    <div>Seen on ' + startTime{flightPath->id} + '.</div>' +
            '    <div>At an altitude of {flightPath->startingAltitude} feet bearing {flightPath->startingTrack}&deg;.</div>' +
            '    <div>Traveling at a speed of {flightPath->startingSpeed} knots.</div>' +
            '    <div>With a vertical rate of {flightPath->startingVerticleRate} feet.</div>' +
            '</p>' +
            '<p><a href="#" onclick="setPosition({flightPath->startingId}); $(\'.sidebar.left\').trigger(\'sidebar:toggle\');">Toggle detailed flight data</a></p>';
        var infowindowStart{flightPath->id} = new google.maps.InfoWindow({
            content: contentStringStart{flightPath->id}
        });

        var markerStart{flightPath->id} = new google.maps.Marker({
          position: {lat: {flightPath->startingLatitude}, lng: {flightPath->startingLongitude}},
          map: map,
          icon: {
            path: genericPlaneSvg,
            scale: 0.4,
            anchor : new google.maps.Point(32, 32),
            fillColor: "green",
            fillOpacity: 1,
            strokeWeight: ((pathsSeen == {flightPath->id}) ? 2 : 1),
            rotation: {flightPath->startingTrack}
          }
        });

        markerStart{flightPath->id}.addListener('click', function() {
            infowindowStart{flightPath->id}.open(map, markerStart{flightPath->id});
        });

        var finishTime{flightPath->id} = dateFormat("{flightPath->finishingTime}", "mmmm dd, yyyy 'at' h:MM TT");

        var contentStringFinish{flightPath->id} = '' +
            '<h4>Sighting Number {flightPath->id}</h4>' +
            '<p><strong>Last Sighting</strong></p>' +
            '<p>' +
            '    <div>Seen on ' + finishTime{flightPath->id} + '.</div>' +
            '    <div>At an altitude of {flightPath->finishingAltitude} feet bearing {flightPath->finishingTrack}&deg;.</div>' +
            '    <div>Traveling at a speed of {flightPath->finishingSpeed} knots.</div>' +
            '    <div>With a vertical rate of {flightPath->finishingVerticleRate} feet.</div>' +
            '</p>' +
            '<p><a href="#" onclick="setPosition({flightPath->finishingId}); $(\'.sidebar.left\').trigger(\'sidebar:toggle\');">Toggle detailed flight data</a></p>';

        var infowindowFinish{flightPath->id} = new google.maps.InfoWindow({
            content: contentStringFinish{flightPath->id}
        });

        var markerFinish{flightPath->id} = new google.maps.Marker({
          position: {lat: {flightPath->finishingLatitude}, lng: {flightPath->finishingLongitude}},
          map: map,
          icon: {
            path: genericPlaneSvg,
            scale: 0.4,
            anchor : new google.maps.Point(32, 32),
            fillColor: "red",
            fillOpacity: 1,
            strokeWeight: ((pathsSeen == {flightPath->id}) ? 2 : 1),
            rotation: {flightPath->finishingTrack}
          }
        });

        markerFinish{flightPath->id}.addListener('click', function() {
            infowindowFinish{flightPath->id}.open(map, markerFinish{flightPath->id});
        });

        json = {flightPath->positions};
        var thisPath = new Array();
        for (var i = 0; i < json.length; i++) {
            thisPath.push(new google.maps.LatLng(json[i].latitude, json[i].longitude));
        }

        var flightPath{flightPath->id} = new google.maps.Polyline({
          path: thisPath,
          geodesic: true,
          strokeColor: 'blue',
          strokeOpacity: ((pathsSeen == {flightPath->id}) ? 1 : 0.3),
          strokeWeight: ((pathsSeen == {flightPath->id}) ? 2 : 1)
        });

        flightPath{flightPath->id}.setMap(map);


        {/foreach}

        // Retain map state.
        loadMapState();

        google.maps.event.addListener(map, 'tilesloaded', tilesLoaded);
        function tilesLoaded() {
            google.maps.event.clearListeners(map, 'tilesloaded');
            google.maps.event.addListener(map, 'zoom_changed', saveMapState);
            google.maps.event.addListener(map, 'dragend', saveMapState);
        }   

        // Map state functions
        function saveMapState() { 
            var mapZoom=map.getZoom(); 
            var mapCentre=map.getCenter(); 
            var mapLat=mapCentre.lat(); 
            var mapLng=mapCentre.lng(); 
            var cookiestring=mapLat+"_"+mapLng+"_"+mapZoom; 
            setCookie("myMapCookie",cookiestring, 30); 
        } 

        function loadMapState() { 
            var gotCookieString=getCookie("myMapCookie"); 
            var splitStr = gotCookieString.split("_");
            var savedMapLat = parseFloat(splitStr[0]);
            var savedMapLng = parseFloat(splitStr[1]);
            var savedMapZoom = parseFloat(splitStr[2]);
            if ((!isNaN(savedMapLat)) && (!isNaN(savedMapLng)) && (!isNaN(savedMapZoom))) {
                map.setCenter(new google.maps.LatLng(savedMapLat,savedMapLng));
                map.setZoom(savedMapZoom);
            }
        }

        function setCookie(c_name,value,exdays) {
            var exdate=new Date();
            exdate.setDate(exdate.getDate() + exdays);
            var c_value=escape(value) + ((exdays==null) ? "" : "; expires="+exdate.toUTCString());
            document.cookie=c_name + "=" + c_value;
        }

        function getCookie(c_name) {
            var i,x,y,ARRcookies=document.cookie.split(";");
            for (i=0;i<ARRcookies.length;i++)
            {
              x=ARRcookies[i].substr(0,ARRcookies[i].indexOf("="));
              y=ARRcookies[i].substr(ARRcookies[i].indexOf("=")+1);
              x=x.replace(/^\s+|\s+$/g,"");
              if (x==c_name)
                {
                return unescape(y);
                }
              }
            return "";
        }

      }
    </script>      
    <script async defer src="https://maps.googleapis.com/maps/api/js?key={setting:googleMapsApiKey}&callback=initMap"></script>
{/area}
