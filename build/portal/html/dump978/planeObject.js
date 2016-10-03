"use strict";

function PlaneObject(icao) {
	// Info about the plane
        this.icao      = icao;
        this.icaorange = findICAORange(icao);
        this.flight    = null;
	this.squawk    = null;
	this.selected  = false;
        this.category  = null;

	// Basic location information
        this.altitude  = null;
        this.speed     = null;
        this.track     = null;
        this.prev_position = null;
        this.position  = null;
        this.position_from_mlat = false
        this.sitedist  = null;

	// Data packet numbers
	this.messages  = null;
        this.rssi      = null;

        // Track history as a series of line segments
        this.track_linesegs = [];
        this.history_size = 0;

	// When was this last updated (receiver timestamp)
        this.last_message_time = null;
        this.last_position_time = null;

        // When was this last updated (seconds before last update)
        this.seen = null;
        this.seen_pos = null;

        // Display info
        this.visible = true;
        this.marker = null;
        this.markerStyle = null;
        this.markerIcon = null;
        this.markerStaticStyle = null;
        this.markerStaticIcon = null;
        this.markerStyleKey = null;
        this.markerSvgKey = null;

        // request metadata
        this.registration = null;
        this.icaotype = null;
        getAircraftData(this.icao).done(function(data) {
                if ("r" in data) {
                        this.registration = data.r;
                }

                if ("t" in data) {
                        this.icaotype = data.t;
                }

                if (this.selected) {
		        refreshSelected();
                }
        }.bind(this));
}

// Appends data to the running track so we can get a visual tail on the plane
// Only useful for a long running browser session.
PlaneObject.prototype.updateTrack = function(estimate_time) {
        if (!this.position)
                return false;
        if (this.position == this.prev_position)
                return false;

        var projHere = ol.proj.fromLonLat(this.position);
        var projPrev;
        if (this.prev_position === null) {
                projPrev = projHere;
        } else {
                projPrev = ol.proj.fromLonLat(this.prev_position);
        }

        this.prev_position = this.position;

        if (this.track_linesegs.length == 0) {
                // Brand new track
                //console.log(this.icao + " new track");
                var newseg = { fixed: new ol.geom.LineString([projHere]),
                               feature: null,
                               head_update: this.last_position_time,
                               tail_update: this.last_position_time,
                               estimated: false,
                               ground: (this.altitude === "ground")
                             };
                this.track_linesegs.push(newseg);
                this.history_size ++;
                return;
        }

        var lastseg = this.track_linesegs[this.track_linesegs.length - 1];
        var elapsed = (this.last_position_time - lastseg.head_update);
        
        var est_track = (elapsed > estimate_time);
        var ground_track = (this.altitude === "ground");
        
        if (est_track) {

                if (!lastseg.estimated) {
                        // >5s gap in data, create a new estimated segment
                        //console.log(this.icao + " switching to estimated");
                        lastseg.fixed.appendCoordinate(projPrev);
                        this.track_linesegs.push({ fixed: new ol.geom.LineString([projPrev, projHere]),
                                                   feature: null,
                                                   head_update: this.last_position_time,
                                                   estimated: true });
                        this.history_size += 2;
                } else {
                        // Keep appending to the existing dashed line; keep every point
                        lastseg.fixed.appendCoordinate(projPrev);
                        lastseg.head_update = this.last_position_time;
                        this.history_size++;
                }

                return true;
        }
        
        if (lastseg.estimated) {
                // We are back to good data (we got two points close in time), switch back to
                // solid lines.
                lastseg = { fixed: new ol.geom.LineString([projPrev]),
                            feature: null,
                            head_update: this.last_position_time,
                            tail_update: this.last_position_time,
                            estimated: false,
                            ground: (this.altitude === "ground") };
                this.track_linesegs.push(lastseg);
                this.history_size ++;
                // continue
        }
        
        if ( (lastseg.ground && this.altitude !== "ground") ||
             (!lastseg.ground && this.altitude === "ground") ) {
                //console.log(this.icao + " ground state changed");
                // Create a new segment as the ground state changed.
                // assume the state changed halfway between the two points
                // FIXME needs reimplementing post-google

                lastseg.fixed.appendCoordinate(projPrev);
                this.track_linesegs.push({ fixed: new ol.geom.LineString([projPrev, projHere]),
                                           feature: null,
                                           head_update: this.last_position_time,
                                           tail_update: this.last_position_time,
                                           estimated: false,
                                           ground: (this.altitude === "ground") });
                this.history_size += 3;
                return true;
        }
        
        // Add more data to the existing track.
        // We only retain some historical points, at 5+ second intervals,
        // plus the most recent point
        if (this.last_position_time - lastseg.tail_update >= 5) {
                // enough time has elapsed; retain the last point and add a new one
                //console.log(this.icao + " retain last point");
                lastseg.fixed.appendCoordinate(projHere);
                lastseg.tail_update = lastseg.head_update;
                this.history_size ++;
        }

        lastseg.head_update = this.last_position_time;
        return true;
};

// This is to remove the line from the screen if we deselect the plane
PlaneObject.prototype.clearLines = function() {
        for (var i = this.track_linesegs.length - 1; i >= 0 ; --i) {
                var seg = this.track_linesegs[i];
                if (seg.feature !== null) {
                        PlaneTrailFeatures.remove(seg.feature);
                        seg.feature = null;
                }
        }
};

PlaneObject.prototype.getMarkerColor = function() {
        // Emergency squawks override everything else
        if (this.squawk in SpecialSquawks)
                return SpecialSquawks[this.squawk].markerColor;

        var h, s, l;

        if (this.altitude === null) {
                h = ColorByAlt.unknown.h;
                s = ColorByAlt.unknown.s;
                l = ColorByAlt.unknown.l;
        } else if (this.altitude === "ground") {
                h = ColorByAlt.ground.h;
                s = ColorByAlt.ground.s;
                l = ColorByAlt.ground.l;
        } else {
                s = ColorByAlt.air.s;
                l = ColorByAlt.air.l;

                // find the pair of points the current altitude lies between,
                // and interpolate the hue between those points
                var hpoints = ColorByAlt.air.h;
                h = hpoints[0].val;
                for (var i = hpoints.length-1; i >= 0; --i) {
                        if (this.altitude > hpoints[i].alt) {
                                if (i == hpoints.length-1) {
                                        h = hpoints[i].val;
                                } else {
                                        h = hpoints[i].val + (hpoints[i+1].val - hpoints[i].val) * (this.altitude - hpoints[i].alt) / (hpoints[i+1].alt - hpoints[i].alt)
                                }
                                break;
                        }
                }
        }

        // If we have not seen a recent position update, change color
        if (this.seen_pos > 15) {
                h += ColorByAlt.stale.h;
                s += ColorByAlt.stale.s;
                l += ColorByAlt.stale.l;
        }

        // If this marker is selected, change color
        if (this.selected){
                h += ColorByAlt.selected.h;
                s += ColorByAlt.selected.s;
                l += ColorByAlt.selected.l;
        }

        // If this marker is a mlat position, change color
        if (this.position_from_mlat) {
                h += ColorByAlt.mlat.h;
                s += ColorByAlt.mlat.s;
                l += ColorByAlt.mlat.l;
        }

        if (h < 0) {
                h = (h % 360) + 360;
        } else if (h >= 360) {
                h = h % 360;
        }

        if (s < 5) s = 5;
        else if (s > 95) s = 95;

        if (l < 5) l = 5;
        else if (l > 95) l = 95;

        return 'hsl(' + (h/5).toFixed(0)*5 + ',' + (s/5).toFixed(0)*5 + '%,' + (l/5).toFixed(0)*5 + '%)'
}

PlaneObject.prototype.updateIcon = function() {
        var col = this.getMarkerColor();
        var opacity = (this.position_from_mlat ? 0.75 : 1.0);
        var outline = (this.position_from_mlat ? OutlineMlatColor : OutlineADSBColor);
        var baseMarker = getBaseMarker(this.category, this.icaotype);
        var weight = ((this.selected ? 2 : 1) / baseMarker.scale).toFixed(1);
        var rotation = (this.track === null ? 0 : this.track);

        var svgKey = col + '!' + outline + '!' + baseMarker.key + '!' + weight;
        var styleKey = opacity + '!' + rotation;

        if (this.markerStyle === null || this.markerIcon === null || this.markerSvgKey != svgKey) {
                //console.log(this.icao + " new icon and style " + this.markerSvgKey + " -> " + svgKey);

                var icon = new ol.style.Icon({
                        anchor: baseMarker.anchor,
                        anchorXUnits: 'pixels',
                        anchorYUnits: 'pixels',
                        scale: baseMarker.scale,
                        imgSize: baseMarker.size,
                        src: svgPathToURI(baseMarker.path, baseMarker.size, outline, weight, col),
                        rotation: (baseMarker.noRotate ? 0 : rotation * Math.PI / 180.0),
                        opacity: opacity,
                        rotateWithView: (baseMarker.noRotate ? false : true)
                });

                if (baseMarker.noRotate) {
                        // the base marker won't be rotated
                        this.markerStaticIcon = icon;
                        this.markerStaticStyle = new ol.style.Style({
                                image: this.markerStaticIcon
                        });

                        // create an arrow that we will rotate around the base marker
                        // to indicate heading

                        var offset = baseMarker.markerRadius * baseMarker.scale + 6;
                        var size = offset * 2;

                        var arrowPath = "M " + offset + ",0 m 4,4 -8,0 4,-4 z";
                        this.markerIcon = new ol.style.Icon({
                                anchor: [offset, offset],
                                anchorXUnits: 'pixels',
                                anchorYUnits: 'pixels',
                                scale: 1.0,
                                imgSize: [size, size],
                                src: svgPathToURI(arrowPath, [size, size], outline, 1, outline),
                                rotation: rotation * Math.PI / 180.0,
                                opacity: opacity,
                                rotateWithView: true
                        });
                        this.markerStyle = new ol.style.Style({
                                image: this.markerIcon
                        });
                } else {
                        this.markerIcon = icon;
                        this.markerStyle = new ol.style.Style({
                                image: this.markerIcon
                        });
                        this.markerStaticIcon = null;
                        this.markerStaticStyle = new ol.style.Style({});
                }

                this.markerStyleKey = styleKey;
                this.markerSvgKey = svgKey;

                if (this.marker !== null) {
                        this.marker.setStyle(this.markerStyle);
                        this.markerStatic.setStyle(this.markerStaticStyle);
                }
        }

        if (this.markerStyleKey != styleKey) {
                //console.log(this.icao + " new rotation");
                this.markerIcon.setRotation(rotation * Math.PI / 180.0);
                this.markerIcon.setOpacity(opacity);
                if (this.staticIcon) {
                        this.staticIcon.setOpacity(opacity);
                }
                this.markerStyleKey = styleKey;
        }

        return true;
};

// Update our data
PlaneObject.prototype.updateData = function(receiver_timestamp, data) {
	// Update all of our data
	this.messages	= data.messages;
        this.rssi       = data.rssi;
	this.last_message_time = receiver_timestamp - data.seen;
        
        if (typeof data.altitude !== "undefined")
		this.altitude	= data.altitude;
        if (typeof data.vert_rate !== "undefined")
		this.vert_rate	= data.vert_rate;
        if (typeof data.speed !== "undefined")
		this.speed	= data.speed;
        if (typeof data.track !== "undefined")
                this.track	= data.track;
        if (typeof data.lat !== "undefined") {
                this.position   = [data.lon, data.lat];
                this.last_position_time = receiver_timestamp - data.seen_pos;

                if (SitePosition !== null) {
                        var WGS84 = new ol.Sphere(6378137);
                        this.sitedist = WGS84.haversineDistance(SitePosition, this.position);
                }

                this.position_from_mlat = false;
                if (typeof data.mlat !== "undefined") {
                        for (var i = 0; i < data.mlat.length; ++i) {
                                if (data.mlat[i] === "lat" || data.mlat[i] == "lon") {
                                        this.position_from_mlat = true;
                                        break;
                                }
                        }
                }
        }
        if (typeof data.flight !== "undefined")
		this.flight	= data.flight;
        if (typeof data.squawk !== "undefined")
		this.squawk	= data.squawk;
        if (typeof data.category !== "undefined")
                this.category	= data.category;
};

PlaneObject.prototype.updateTick = function(receiver_timestamp, last_timestamp) {
        // recompute seen and seen_pos
        this.seen = receiver_timestamp - this.last_message_time;
        this.seen_pos = (this.last_position_time === null ? null : receiver_timestamp - this.last_position_time);
        
	// If no packet in over 58 seconds, clear the plane.
	if (this.seen > 58) {
                if (this.visible) {
                        //console.log("hiding " + this.icao);
                        this.clearMarker();
                        this.visible = false;
			if (SelectedPlane == this.icao)
                                selectPlaneByHex(null,false);
                }
	} else {
                this.visible = true;
                if (this.position !== null && (this.selected || this.seen_pos < 60)) {
			if (this.updateTrack(receiver_timestamp - last_timestamp + (this.position_from_mlat ? 30 : 5))) {
                                this.updateLines();
                                this.updateMarker(true);
                        } else { 
                                this.updateMarker(false); // didn't move
                        }
                } else {
			this.clearMarker();
		}
	}
};

PlaneObject.prototype.clearMarker = function() {
	if (this.marker) {
                PlaneIconFeatures.remove(this.marker);
                PlaneIconFeatures.remove(this.markerStatic);
                /* FIXME google.maps.event.clearListeners(this.marker, 'click'); */
                this.marker = this.markerStatic = null;
	}
};

// Update our marker on the map
PlaneObject.prototype.updateMarker = function(moved) {
        if (!this.visible || this.position == null) {
                this.clearMarker();
                return;
        }
        
        this.updateIcon();
        if (this.marker) {
                if (moved) {
                        this.marker.setGeometry(new ol.geom.Point(ol.proj.fromLonLat(this.position)));
                        this.markerStatic.setGeometry(new ol.geom.Point(ol.proj.fromLonLat(this.position)));
                }
        } else {
                this.marker = new ol.Feature(new ol.geom.Point(ol.proj.fromLonLat(this.position)));
                this.marker.hex = this.icao;
                this.marker.setStyle(this.markerStyle);
                PlaneIconFeatures.push(this.marker);

                this.markerStatic = new ol.Feature(new ol.geom.Point(ol.proj.fromLonLat(this.position)));
                this.markerStatic.hex = this.icao;
                this.markerStatic.setStyle(this.markerStaticStyle);
                PlaneIconFeatures.push(this.markerStatic);
	}
};

// Update our planes tail line,
PlaneObject.prototype.updateLines = function() {
        if (!this.selected)
                return;

        if (this.track_linesegs.length == 0)
                return;

        var estimateStyle = new ol.style.Style({
                stroke: new ol.style.Stroke({
                        color: '#a08080',
                        width: 1.5,
                        lineDash: [3, 3]
                })
        });

        var airStyle = new ol.style.Style({
                stroke: new ol.style.Stroke({
                        color: '#000000',
                        width: 2
                })
        });

        var groundStyle = new ol.style.Style({
                stroke: new ol.style.Stroke({
                        color: '#408040',
                        width: 2
                })
        });

        // create the new latest-position line
        var lastseg = this.track_linesegs[this.track_linesegs.length - 1];
        var lastfixed = lastseg.fixed.getCoordinateAt(1.0);
        var geom = new ol.geom.LineString([lastfixed, ol.proj.fromLonLat(this.position)]);
        var feature = new ol.Feature(geom);
        feature.setStyle(this.altitude === 'ground' ? groundStyle : airStyle);

        if (PlaneTrailFeatures.length == 0) {
                PlaneTrailFeatures.push(feature);
        } else {
                PlaneTrailFeatures.setAt(0, feature);
        }

        // create any missing fixed line features
        for (var i = 0; i < this.track_linesegs.length; ++i) {
                var seg = this.track_linesegs[i];
                if (seg.feature === null) {
                        seg.feature = new ol.Feature(seg.fixed);
                        if (seg.estimated) {
                                seg.feature.setStyle(estimateStyle);
                        } else if (seg.ground) {
                                seg.feature.setStyle(groundStyle);
                        } else {
                                seg.feature.setStyle(airStyle);
                        }

                        PlaneTrailFeatures.push(seg.feature);
                }
        }
};

PlaneObject.prototype.destroy = function() {
        this.clearLines();
        this.clearMarker();
};
