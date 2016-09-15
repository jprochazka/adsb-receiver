// -*- mode: javascript; indent-tabs-mode: nil; c-basic-offset: 8 -*-
"use strict";

// Define our global variables
var OLMap         = null;
var StaticFeatures = new ol.Collection();
var PlaneIconFeatures = new ol.Collection();
var PlaneTrailFeatures = new ol.Collection();
var Planes        = {};
var PlanesOrdered = [];
var SelectedPlane = null;
var FollowSelected = false;

var SpecialSquawks = {
        '7500' : { cssClass: 'squawk7500', markerColor: 'rgb(255, 85, 85)', text: 'Aircraft Hijacking' },
        '7600' : { cssClass: 'squawk7600', markerColor: 'rgb(0, 255, 255)', text: 'Radio Failure' },
        '7700' : { cssClass: 'squawk7700', markerColor: 'rgb(255, 255, 0)', text: 'General Emergency' }
};

// Get current map settings
var CenterLat, CenterLon, ZoomLvl, MapType;

var Dump1090Version = "unknown version";
var RefreshInterval = 1000;

var PlaneRowTemplate = null;

var TrackedAircraft = 0;
var TrackedAircraftPositions = 0;
var TrackedHistorySize = 0;

var SitePosition = null;

var ReceiverClock = null;

var LastReceiverTimestamp = 0;
var StaleReceiverCount = 0;
var FetchPending = null;

var MessageCountHistory = [];
var MessageRate = 0;

var NBSP='\u00a0';

function processReceiverUpdate(data) {
	// Loop through all the planes in the data packet
        var now = data.now;
        var acs = data.aircraft;

        // Detect stats reset
        if (MessageCountHistory.length > 0 && MessageCountHistory[MessageCountHistory.length-1].messages > data.messages) {
                MessageCountHistory = [{'time' : MessageCountHistory[MessageCountHistory.length-1].time,
                                        'messages' : 0}];
        }

        // Note the message count in the history
        MessageCountHistory.push({ 'time' : now, 'messages' : data.messages});
        // .. and clean up any old values
        if ((now - MessageCountHistory[0].time) > 30)
                MessageCountHistory.shift();

	for (var j=0; j < acs.length; j++) {
                var ac = acs[j];
                var hex = ac.hex;
                var plane = null;

		// Do we already have this plane object in Planes?
		// If not make it.

		if (Planes[hex]) {
			plane = Planes[hex];
		} else {
			plane = new PlaneObject(hex);
                        plane.tr = PlaneRowTemplate.cloneNode(true);

                        if (hex[0] === '~') {
                                // Non-ICAO address
                                plane.tr.cells[0].textContent = hex.substring(1);
                                $(plane.tr).css('font-style', 'italic');
                        } else {
                                plane.tr.cells[0].textContent = hex;
                        }

                        // set flag image if available
                        if (ShowFlags && plane.icaorange.flag_image !== null) {
                                $('img', plane.tr.cells[1]).attr('src', FlagPath + plane.icaorange.flag_image);
                                $('img', plane.tr.cells[1]).attr('title', plane.icaorange.country);
                        } else {
                                $('img', plane.tr.cells[1]).css('display', 'none');
                        }

                        plane.tr.addEventListener('click', function(h, evt) {
                                selectPlaneByHex(h, false);
                                evt.preventDefault();
                        }.bind(undefined, hex));

                        plane.tr.addEventListener('dblclick', function(h, evt) {
                                selectPlaneByHex(h, true);
                                evt.preventDefault();
                        }.bind(undefined, hex));
                        
                        Planes[hex] = plane;
                        PlanesOrdered.push(plane);
		}

		// Call the function update
		plane.updateData(now, ac);
	}
}

function fetchData() {
        if (FetchPending !== null && FetchPending.state() == 'pending') {
                // don't double up on fetches, let the last one resolve
                return;
        }

	FetchPending = $.ajax({ url: 'data/aircraft.json',
                                timeout: 5000,
                                cache: false,
                                dataType: 'json' });
        FetchPending.done(function(data) {
                var now = data.now;

                processReceiverUpdate(data);

                // update timestamps, visibility, history track for all planes - not only those updated
                for (var i = 0; i < PlanesOrdered.length; ++i) {
                        var plane = PlanesOrdered[i];
                        plane.updateTick(now, LastReceiverTimestamp);
                }
                
		refreshTableInfo();
		refreshSelected();
                
                if (ReceiverClock) {
                        var rcv = new Date(now * 1000);
                        ReceiverClock.render(rcv.getUTCHours(),rcv.getUTCMinutes(),rcv.getUTCSeconds());
                }

                // Check for stale receiver data
                if (LastReceiverTimestamp === now) {
                        StaleReceiverCount++;
                        if (StaleReceiverCount > 5) {
                                $("#update_error_detail").text("The data from dump978 hasn't been updated in a while. Maybe dump978 is no longer running?");
                                $("#update_error").css('display','block');
                        }
                } else { 
                        StaleReceiverCount = 0;
                        LastReceiverTimestamp = now;
                        $("#update_error").css('display','none');
                }
	});

        FetchPending.fail(function(jqxhr, status, error) {
                $("#update_error_detail").text("AJAX call failed (" + status + (error ? (": " + error) : "") + "). Maybe dump978 is no longer running?");
                $("#update_error").css('display','block');
        });
}

var PositionHistorySize = 0;
function initialize() {
        // Set page basics
        document.title = PageName;
        $("#infoblock_name").text(PageName);

        PlaneRowTemplate = document.getElementById("plane_row_template");

        if (!ShowClocks) {
                $('#timestamps').css('display','none');
        } else {
                // Create the clocks.
		new CoolClock({
			canvasId:       "utcclock",
			skinId:         "classic",
			displayRadius:  40,
			showSecondHand: true,
			gmtOffset:      "0", // this has to be a string!
			showDigital:    false,
			logClock:       false,
			logClockRev:    false
		});

		ReceiverClock = new CoolClock({
			canvasId:       "receiverclock",
			skinId:         "classic",
			displayRadius:  40,
			showSecondHand: true,
			gmtOffset:      null,
			showDigital:    false,
			logClock:       false,
			logClockRev:    false
		});

                // disable ticking on the receiver clock, we will update it ourselves
                ReceiverClock.tick = (function(){})
        }

        $("#loader").removeClass("hidden");
        
        // Get receiver metadata, reconfigure using it, then continue
        // with initialization
        $.ajax({ url: 'data/receiver.json',
                 timeout: 5000,
                 cache: false,
                 dataType: 'json' })

                .done(function(data) {
                        if (typeof data.lat !== "undefined") {
                                SiteShow = true;
                                SiteLat = data.lat;
                                SiteLon = data.lon;
                                DefaultCenterLat = data.lat;
                                DefaultCenterLon = data.lon;
                        }
                        
                        Dump1090Version = data.version;
                        RefreshInterval = data.refresh;
                        PositionHistorySize = data.history;
                })

                .always(function() {
                        initialize_map();
                        start_load_history();
                });
}

var CurrentHistoryFetch = null;
var PositionHistoryBuffer = []
function start_load_history() {
        if (PositionHistorySize > 0) {
                $("#loader_progress").attr('max',PositionHistorySize);
                console.log("Starting to load history (" + PositionHistorySize + " items)");
                load_history_item(0);
        } else {
                end_load_history();
        }
}

function load_history_item(i) {
        if (i >= PositionHistorySize) {
                end_load_history();
                return;
        }

        console.log("Loading history #" + i);
        $("#loader_progress").attr('value',i);

        $.ajax({ url: 'data/history_' + i + '.json',
                 timeout: 5000,
                 cache: false,
                 dataType: 'json' })

                .done(function(data) {
                        PositionHistoryBuffer.push(data);
                        load_history_item(i+1);
                })

                .fail(function(jqxhr, status, error) {
                        // No more history
                        end_load_history();
                });
}

function end_load_history() {
        $("#loader").addClass("hidden");

        console.log("Done loading history");

        if (PositionHistoryBuffer.length > 0) {
                var now, last=0;

                // Sort history by timestamp
                console.log("Sorting history");
                PositionHistoryBuffer.sort(function(x,y) { return (x.now - y.now); });

                // Process history
                for (var h = 0; h < PositionHistoryBuffer.length; ++h) {
                        now = PositionHistoryBuffer[h].now;
                        console.log("Applying history " + h + "/" + PositionHistoryBuffer.length + " at: " + now);
                        processReceiverUpdate(PositionHistoryBuffer[h]);

                        // update track
                        console.log("Updating tracks at: " + now);
                        for (var i = 0; i < PlanesOrdered.length; ++i) {
                                var plane = PlanesOrdered[i];
                                plane.updateTrack((now - last) + 1);
                        }

                        last = now;
                }

                // Final pass to update all planes to their latest state
                console.log("Final history cleanup pass");
                for (var i = 0; i < PlanesOrdered.length; ++i) {
                        var plane = PlanesOrdered[i];
                        plane.updateTick(now);
                }

                LastReceiverTimestamp = last;
        }

        PositionHistoryBuffer = null;

        console.log("Completing init");

        refreshTableInfo();
        refreshSelected();
        reaper();

        // Setup our timer to poll from the server.
        window.setInterval(fetchData, RefreshInterval);
        window.setInterval(reaper, 60000);

        // And kick off one refresh immediately.
        fetchData();

}

// Make a LineString with 'points'-number points
// that is a closed circle on the sphere such that the
// great circle distance from 'center' to each point is
// 'radius' meters
function make_geodesic_circle(center, radius, points) {
        var angularDistance = radius / 6378137.0;
        var lon1 = center[0] * Math.PI / 180.0;
        var lat1 = center[1] * Math.PI / 180.0;
        var geom = new ol.geom.LineString();
        for (var i = 0; i <= points; ++i) {
                var bearing = i * 2 * Math.PI / points;

                var lat2 = Math.asin( Math.sin(lat1)*Math.cos(angularDistance) +
                                      Math.cos(lat1)*Math.sin(angularDistance)*Math.cos(bearing) );
                var lon2 = lon1 + Math.atan2(Math.sin(bearing)*Math.sin(angularDistance)*Math.cos(lat1),
                                             Math.cos(angularDistance)-Math.sin(lat1)*Math.sin(lat2));

                lat2 = lat2 * 180.0 / Math.PI;
                lon2 = lon2 * 180.0 / Math.PI;
                geom.appendCoordinate([lon2, lat2]);
        }
        return geom;
}

// Initalizes the map and starts up our timers to call various functions
function initialize_map() {
        // Load stored map settings if present
        CenterLat = Number(localStorage['CenterLat']) || DefaultCenterLat;
        CenterLon = Number(localStorage['CenterLon']) || DefaultCenterLon;
        ZoomLvl = Number(localStorage['ZoomLvl']) || DefaultZoomLvl;
        MapType = localStorage['MapType'];

        // Set SitePosition, initialize sorting
        if (SiteShow && (typeof SiteLat !==  'undefined') && (typeof SiteLon !==  'undefined')) {
	        SitePosition = [SiteLon, SiteLat];
                sortByDistance();
        } else {
	        SitePosition = null;
                PlaneRowTemplate.cells[6].style.display = 'none'; // hide distance column
                document.getElementById("distance").style.display = 'none'; // hide distance header
                sortByAltitude();
        }

        // Maybe hide flag info
        if (!ShowFlags) {
                PlaneRowTemplate.cells[1].style.display = 'none'; // hide flag column
                document.getElementById("flag").style.display = 'none'; // hide flag header
                document.getElementById("infoblock_country").style.display = 'none'; // hide country row
        }

        // Initialize OL3

        var layers = createBaseLayers();

        var iconsLayer = new ol.layer.Vector({
                name: 'ac_positions',
                type: 'overlay',
                title: 'Aircraft positions',
                source: new ol.source.Vector({
                        features: PlaneIconFeatures,
                })
        });

        layers.push(new ol.layer.Group({
                title: 'Overlays',
                layers: [
                        new ol.layer.Vector({
                                name: 'site_pos',
                                type: 'overlay',
                                title: 'Site position and range rings',
                                source: new ol.source.Vector({
                                        features: StaticFeatures,
                                })
                        }),

                        new ol.layer.Vector({
                                name: 'ac_trail',
                                type: 'overlay',
                                title: 'Selected aircraft trail',
                                source: new ol.source.Vector({
                                        features: PlaneTrailFeatures,
                                })
                        }),

                        iconsLayer
                ]
        }));

        var foundType = false;

        ol.control.LayerSwitcher.forEachRecursive(layers, function(lyr) {
                if (!lyr.get('name'))
                        return;

                if (lyr.get('type') === 'base') {
                        if (MapType === lyr.get('name')) {
                                foundType = true;
                                lyr.setVisible(true);
                        } else {
                                lyr.setVisible(false);
                        }

                        lyr.on('change:visible', function(evt) {
                                if (evt.target.getVisible()) {
                                        MapType = localStorage['MapType'] = evt.target.get('name');
                                }
                        });
                } else if (lyr.get('type') === 'overlay') {
                        var visible = localStorage['layer_' + lyr.get('name')];
                        if (visible != undefined) {
                                // javascript, why must you taunt me with gratuitous type problems
                                lyr.setVisible(visible === "true");
                        }

                        lyr.on('change:visible', function(evt) {
                                localStorage['layer_' + evt.target.get('name')] = evt.target.getVisible();
                        });
                }
        })

        if (!foundType) {
                ol.control.LayerSwitcher.forEachRecursive(layers, function(lyr) {
                        if (foundType)
                                return;
                        if (lyr.get('type') === 'base') {
                                lyr.setVisible(true);
                                foundType = true;
                        }
                });
        }

        OLMap = new ol.Map({
                target: 'map_canvas',
                layers: layers,
                view: new ol.View({
                        center: ol.proj.fromLonLat([CenterLon, CenterLat]),
                        zoom: ZoomLvl
                }),
                controls: [new ol.control.Zoom(),
                           new ol.control.Rotate(),
                           new ol.control.Attribution({collapsed: false}),
                           new ol.control.ScaleLine({units: Metric ? "metric" : "nautical"}),
                           new ol.control.LayerSwitcher()
                          ],
                loadTilesWhileAnimating: true,
                loadTilesWhileInteracting: true
        });

	// Listeners for newly created Map
        OLMap.getView().on('change:center', function(event) {
                var center = ol.proj.toLonLat(OLMap.getView().getCenter(), OLMap.getView().getProjection());
                localStorage['CenterLon'] = center[0]
                localStorage['CenterLat'] = center[1]
                if (FollowSelected) {
                        // On manual navigation, disable follow
                        var selected = Planes[SelectedPlane];
                        if (Math.abs(center[0] - selected.position[0]) > 0.0001 &&
                            Math.abs(center[1] - selected.position[1]) > 0.0001) {
                                FollowSelected = false;
                                refreshSelected();
                        }
                }
        });
    
        OLMap.getView().on('change:resolution', function(event) {
                localStorage['ZoomLvl']  = OLMap.getView().getZoom();
        });

        OLMap.on(['click', 'dblclick'], function(evt) {
                var hex = evt.map.forEachFeatureAtPixel(evt.pixel,
                                                        function(feature, layer) {
                                                                return feature.hex;
                                                        },
                                                        null,
                                                        function(layer) {
                                                                return (layer === iconsLayer);
                                                        },
                                                        null);
                if (hex) {
                        selectPlaneByHex(hex, (evt.type === 'dblclick'));
                        evt.stopPropagation();
                }
        });

	// Add home marker if requested
	if (SitePosition) {
                var markerStyle = new ol.style.Style({
                        image: new ol.style.Circle({
                                radius: 7,
                                snapToPixel: false,
                                fill: new ol.style.Fill({color: 'black'}),
                                stroke: new ol.style.Stroke({
                                        color: 'white', width: 2
                                })
                        })
                });

                var feature = new ol.Feature(new ol.geom.Point(ol.proj.fromLonLat(SitePosition)));
                feature.setStyle(markerStyle);
                StaticFeatures.push(feature);
        
                if (SiteCircles) {
                        var circleStyle = new ol.style.Style({
                                fill: null,
                                stroke: new ol.style.Stroke({
                                        color: '#000000',
                                        width: 1
                                })
                        });

                        for (var i=0; i < SiteCirclesDistances.length; ++i) {
                                var distance = SiteCirclesDistances[i] * 1000.0;
                                if (!Metric) {
                                        distance *= 1.852;
                                }

                                var circle = make_geodesic_circle(SitePosition, distance, 360);
                                circle.transform('EPSG:4326', 'EPSG:3857');
                                var feature = new ol.Feature(circle);
                                feature.setStyle(circleStyle);
                                StaticFeatures.push(feature);
                        }
                }
	}

        // Add terrain-limit rings. To enable this:
        //
        //  create a panorama for your receiver location on heywhatsthat.com
        //
        //  note the "view" value from the URL at the top of the panorama
        //    i.e. the XXXX in http://www.heywhatsthat.com/?view=XXXX
        //
        // fetch a json file from the API for the altitudes you want to see:
        //
        //  wget -O /usr/share/dump1090-mutability/html/upintheair.json \
        //    'http://www.heywhatsthat.com/api/upintheair.json?id=XXXX&refraction=0.25&alts=3048,9144'
        //
        // NB: altitudes are in _meters_, you can specify a list of altitudes

        // kick off an ajax request that will add the rings when it's done
        var request = $.ajax({ url: 'upintheair.json',
                               timeout: 5000,
                               cache: true,
                               dataType: 'json' });
        request.done(function(data) {
                var ringStyle = new ol.style.Style({
                        fill: null,
                        stroke: new ol.style.Stroke({
                                color: '#000000',
                                width: 1
                        })
                });

                for (var i = 0; i < data.rings.length; ++i) {
                        var geom = new ol.geom.LineString();
                        var points = data.rings[i].points;
                        if (points.length > 0) {
                                for (var j = 0; j < points.length; ++j) {
                                        geom.appendCoordinate([ points[j][1], points[j][0] ]);
                                }
                                geom.appendCoordinate([ points[0][1], points[0][0] ]);
                                geom.transform('EPSG:4326', 'EPSG:3857');

                                var feature = new ol.Feature(geom);
                                feature.setStyle(ringStyle);
                                StaticFeatures.push(feature);
                        }
                }
        });

        request.fail(function(jqxhr, status, error) {
                // no rings available, do nothing
        });
}

// This looks for planes to reap out of the master Planes variable
function reaper() {
        //console.log("Reaping started..");

	// Look for planes where we have seen no messages for >300 seconds
        var newPlanes = [];
        for (var i = 0; i < PlanesOrdered.length; ++i) {
                var plane = PlanesOrdered[i];
                if (plane.seen > 300) {
			// Reap it.                                
                        //console.log("Reaping " + plane.icao);
                        //console.log("parent " + plane.tr.parentNode);
                        plane.tr.parentNode.removeChild(plane.tr);
                        plane.tr = null;
			delete Planes[plane.icao];
                        plane.destroy();
		} else {
                        // Keep it.
                        newPlanes.push(plane);
		}
	};

        PlanesOrdered = newPlanes;
        refreshTableInfo();
        refreshSelected();
}

// Page Title update function
function refreshPageTitle() {
        if (!PlaneCountInTitle && !MessageRateInTitle)
                return;

        var subtitle = "";

        if (PlaneCountInTitle) {
                subtitle += TrackedAircraftPositions + '/' + TrackedAircraft;
        }

        if (MessageRateInTitle) {
                if (subtitle) subtitle += ' | ';
                subtitle += MessageRate.toFixed(1) + '/s';
        }

        document.title = PageName + ' - ' + subtitle;
}

// Refresh the detail window about the plane
function refreshSelected() {
        if (MessageCountHistory.length > 1) {
                var message_time_delta = MessageCountHistory[MessageCountHistory.length-1].time - MessageCountHistory[0].time;
                var message_count_delta = MessageCountHistory[MessageCountHistory.length-1].messages - MessageCountHistory[0].messages;
                if (message_time_delta > 0)
                        MessageRate = message_count_delta / message_time_delta;
        } else {
                MessageRate = null;
        }

	refreshPageTitle();
       
        var selected = false;
	if (typeof SelectedPlane !== 'undefined' && SelectedPlane != "ICAO" && SelectedPlane != null) {
    	        selected = Planes[SelectedPlane];
        }
        
        if (!selected) {
                $('#selected_infoblock').css('display','none');
                $('#dump1090_infoblock').css('display','block');
                $('#dump1090_version').text(Dump1090Version);
                $('#dump1090_total_ac').text(TrackedAircraft);
                $('#dump1090_total_ac_positions').text(TrackedAircraftPositions);
                $('#dump1090_total_history').text(TrackedHistorySize);

                if (MessageRate !== null) {
                        $('#dump1090_message_rate').text(MessageRate.toFixed(1));
                } else {
                        $('#dump1090_message_rate').text("n/a");
                }

                return;
        }
        
        $('#dump1090_infoblock').css('display','none');
        $('#selected_infoblock').css('display','block');

        $('#selected_flightaware_link').attr('href','//flightaware.com/live/modes/'+selected.icao+'/redirect');
        
        if (selected.flight !== null && selected.flight !== "") {
                $('#selected_callsign').text(selected.flight);
                $('#selected_links').css('display','inline');
                $('#selected_fr24_link').attr('href','http://fr24.com/'+selected.flight);
                $('#selected_flightstats_link').attr('href','http://www.flightstats.com/go/FlightStatus/flightStatusByFlight.do?flightNumber='+selected.flight);
    $('#selected_planefinder_link').attr('href','https://planefinder.net/flight/'+selected.flight);
        } else {
                $('#selected_callsign').text('n/a');
                $('#selected_links').css('display','none');
        }

        if (selected.registration !== null) {
                $('#selected_registration').text(selected.registration);
        } else {
                $('#selected_registration').text("");
        }

        if (selected.icaotype !== null) {
                $('#selected_icaotype').text(selected.icaotype);
        } else {
                $('#selected_icaotype').text("");
        }

        var emerg = document.getElementById('selected_emergency');
        if (selected.squawk in SpecialSquawks) {
                emerg.className = SpecialSquawks[selected.squawk].cssClass;
                emerg.textContent = NBSP + 'Squawking: ' + SpecialSquawks[selected.squawk].text + NBSP ;
        } else {
                emerg.className = 'hidden';
        }

        $("#selected_altitude").text(format_altitude_long(selected.altitude, selected.vert_rate));

        if (selected.squawk === null || selected.squawk === '0000') {
                $('#selected_squawk').text('n/a');
        } else {
                $('#selected_squawk').text(selected.squawk);
        }
	
        $('#selected_speed').text(format_speed_long(selected.speed));
        $('#selected_icao').text(selected.icao.toUpperCase());
        $('#airframes_post_icao').attr('value',selected.icao);
	$('#selected_track').text(format_track_long(selected.track));

        if (selected.seen <= 1) {
                $('#selected_seen').text('now');
        } else {
                $('#selected_seen').text(selected.seen.toFixed(1) + 's');
        }

        $('#selected_country').text(selected.icaorange.country);
        if (ShowFlags && selected.icaorange.flag_image !== null) {
                $('#selected_flag').removeClass('hidden');
                $('#selected_flag img').attr('src', FlagPath + selected.icaorange.flag_image);
                $('#selected_flag img').attr('title', selected.icaorange.country);
        } else {
                $('#selected_flag').addClass('hidden');
        }

	if (selected.position === null) {
                $('#selected_position').text('n/a');
                $('#selected_follow').addClass('hidden');
        } else {
                var mlat_bit = (selected.position_from_mlat ? "MLAT: " : "");
                if (selected.seen_pos > 1) {
                        $('#selected_position').text(mlat_bit + format_latlng(selected.position) + " (" + selected.seen_pos.toFixed(1) + "s)");
                } else {
                        $('#selected_position').text(mlat_bit + format_latlng(selected.position));
                }
                $('#selected_follow').removeClass('hidden');
                if (FollowSelected) {
                        $('#selected_follow').css('font-weight', 'bold');
                        OLMap.getView().setCenter(ol.proj.fromLonLat(selected.position));
                } else {
                        $('#selected_follow').css('font-weight', 'normal');
                }
	}
        
        $('#selected_sitedist').text(format_distance_long(selected.sitedist));
        $('#selected_rssi').text(selected.rssi.toFixed(1) + ' dBFS');
}

// Refreshes the larger table of all the planes
function refreshTableInfo() {
        var show_squawk_warning = false;

        TrackedAircraft = 0
        TrackedAircraftPositions = 0
        TrackedHistorySize = 0

        for (var i = 0; i < PlanesOrdered.length; ++i) {
		var tableplane = PlanesOrdered[i];
                TrackedHistorySize += tableplane.history_size;
		if (!tableplane.visible) {
                        tableplane.tr.className = "plane_table_row hidden";
                } else {
                        TrackedAircraft++;
                        var classes = "plane_table_row";

		        if (tableplane.position !== null && tableplane.seen_pos < 60) {
                                ++TrackedAircraftPositions;
                                if (tableplane.position_from_mlat)
                                        classes += " mlat";
				else
                                        classes += " vPosition";
			}
			if (tableplane.icao == SelectedPlane)
                                classes += " selected";
                        
                        if (tableplane.squawk in SpecialSquawks) {
                                classes = classes + " " + SpecialSquawks[tableplane.squawk].cssClass;
                                show_squawk_warning = true;
			}			                

                        // ICAO doesn't change
                        tableplane.tr.cells[2].textContent = (tableplane.flight !== null ? tableplane.flight : "");
                        tableplane.tr.cells[3].textContent = (tableplane.squawk !== null ? tableplane.squawk : "");
                        tableplane.tr.cells[4].textContent = format_altitude_brief(tableplane.altitude, tableplane.vert_rate);
                        tableplane.tr.cells[5].textContent = format_speed_brief(tableplane.speed);
                        tableplane.tr.cells[6].textContent = format_distance_brief(tableplane.sitedist);
                        tableplane.tr.cells[7].textContent = format_track_brief(tableplane.track);
                        tableplane.tr.cells[8].textContent = tableplane.messages;
                        tableplane.tr.cells[9].textContent = tableplane.seen.toFixed(0);
                        tableplane.tr.className = classes;
		}
	}

	if (show_squawk_warning) {
                $("#SpecialSquawkWarning").css('display','block');
        } else {
                $("#SpecialSquawkWarning").css('display','none');
        }

        resortTable();
}

//
// ---- table sorting ----
//

function compareAlpha(xa,ya) {
        if (xa === ya)
                return 0;
        if (xa < ya)
                return -1;
        return 1;
}

function compareNumeric(xf,yf) {
        if (Math.abs(xf - yf) < 1e-9)
                return 0;

        return xf - yf;
}

function sortByICAO()     { sortBy('icao',    compareAlpha,   function(x) { return x.icao; }); }
function sortByFlight()   { sortBy('flight',  compareAlpha,   function(x) { return x.flight; }); }
function sortBySquawk()   { sortBy('squawk',  compareAlpha,   function(x) { return x.squawk; }); }
function sortByAltitude() { sortBy('altitude',compareNumeric, function(x) { return (x.altitude == "ground" ? -1e9 : x.altitude); }); }
function sortBySpeed()    { sortBy('speed',   compareNumeric, function(x) { return x.speed; }); }
function sortByDistance() { sortBy('sitedist',compareNumeric, function(x) { return x.sitedist; }); }
function sortByTrack()    { sortBy('track',   compareNumeric, function(x) { return x.track; }); }
function sortByMsgs()     { sortBy('msgs',    compareNumeric, function(x) { return x.messages; }); }
function sortBySeen()     { sortBy('seen',    compareNumeric, function(x) { return x.seen; }); }
function sortByCountry()  { sortBy('country', compareAlpha,   function(x) { return x.icaorange.country; }); }

var sortId = '';
var sortCompare = null;
var sortExtract = null;
var sortAscending = true;

function sortFunction(x,y) {
        var xv = x._sort_value;
        var yv = y._sort_value;

        // always sort missing values at the end, regardless of
        // ascending/descending sort
        if (xv == null && yv == null) return x._sort_pos - y._sort_pos;
        if (xv == null) return 1;
        if (yv == null) return -1;

        var c = sortAscending ? sortCompare(xv,yv) : sortCompare(yv,xv);
        if (c !== 0) return c;

        return x._sort_pos - y._sort_pos;
}

function resortTable() {
        // number the existing rows so we can do a stable sort
        // regardless of whether sort() is stable or not.
        // Also extract the sort comparison value.
        for (var i = 0; i < PlanesOrdered.length; ++i) {
                PlanesOrdered[i]._sort_pos = i;
                PlanesOrdered[i]._sort_value = sortExtract(PlanesOrdered[i]);
        }

        PlanesOrdered.sort(sortFunction);
        
        var tbody = document.getElementById('tableinfo').tBodies[0];
        for (var i = 0; i < PlanesOrdered.length; ++i) {
                tbody.appendChild(PlanesOrdered[i].tr);
        }
}

function sortBy(id,sc,se) {
        if (id === sortId) {
                sortAscending = !sortAscending;
                PlanesOrdered.reverse(); // this correctly flips the order of rows that compare equal
        } else {
                sortAscending = true;
        }

        sortId = id;
        sortCompare = sc;
        sortExtract = se;

        resortTable();
}

function selectPlaneByHex(hex,autofollow) {
        //console.log("select: " + hex);
	// If SelectedPlane has something in it, clear out the selected
	if (SelectedPlane != null) {
		Planes[SelectedPlane].selected = false;
		Planes[SelectedPlane].clearLines();
		Planes[SelectedPlane].updateMarker();
                $(Planes[SelectedPlane].tr).removeClass("selected");
	}

	// If we are clicking the same plane, we are deselecting it.
        // (unless it was a doubleclick..)
	if (SelectedPlane === hex && !autofollow) {
                hex = null;
        }

        if (hex !== null) {
		// Assign the new selected
		SelectedPlane = hex;
		Planes[SelectedPlane].selected = true;
		Planes[SelectedPlane].updateLines();
		Planes[SelectedPlane].updateMarker();
                $(Planes[SelectedPlane].tr).addClass("selected");
	} else { 
		SelectedPlane = null;
	}

        if (SelectedPlane !== null && autofollow) {
                FollowSelected = true;
                if (OLMap.getView().getZoom() < 8)
                        OLMap.getView().setZoom(8);
        } else {
                FollowSelected = false;
        } 

        refreshSelected();
}

function toggleFollowSelected() {
        FollowSelected = !FollowSelected;
        if (FollowSelected && OLMap.getView().getZoom() < 8)
                OLMap.getView().setZoom(8);
        refreshSelected();
}

function resetMap() {
        // Reset localStorage values and map settings
        localStorage['CenterLat'] = CenterLat = DefaultCenterLat;
        localStorage['CenterLon'] = CenterLon = DefaultCenterLon;
        localStorage['ZoomLvl']   = ZoomLvl = DefaultZoomLvl;

        // Set and refresh
        OLMap.getView().setZoom(ZoomLvl);
	OLMap.getView().setCenter(ol.proj.fromLonLat([CenterLon, CenterLat]));
	
	selectPlaneByHex(null,false);
}
