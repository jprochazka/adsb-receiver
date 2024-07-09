import { Component, OnInit } from '@angular/core';
import 'ol/ol.css';
import Map from 'ol/Map';
import Feature from 'ol/Feature';
import Point from 'ol/geom/Point';
import LineString from 'ol/geom/LineString';
import VectorSource from 'ol/source/Vector';
import VectorLayer from 'ol/layer/Vector';
import TileLayer from 'ol/layer/Tile';
import View from 'ol/View';
import Style from 'ol/style/Style';
import Icon from 'ol/style/Icon';
import { fromLonLat } from 'ol/proj.js';
import { OSM } from 'ol/source';

@Component({
  selector: 'app-flight-history',
  standalone: true,
  imports: [],
  templateUrl: './flight-history.component.html',
  styleUrl: './flight-history.component.scss'
})
export class FlightHistoryComponent implements OnInit {
  public map!: Map
  public start!: Feature;
  public end!: Feature;
  public plot!: Feature;
  public vectorSource!: VectorSource
  public vectorLayer!: VectorLayer<any>;
  public tileLayer!: TileLayer<any>;
  public view!: View;

  ngOnInit(): void {

    var airlinerSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 25 26" width="25px" height="26px"><defs><style>.cls-1{fill:aircraft_color_fill;}.cls-2{fill:aircraft_color_stroke;}</style></defs><title>airliner_live</title><g id="Layer_2" data-name="Layer 2"><g id="Airliner"><path class="cls-1" d="M12.51,25.75c-.26,0-.74-.71-.86-1.41l-3.33.86L8,25.29l.08-1.41.11-.07c1.13-.68,2.68-1.64,3.2-2-.37-1.06-.51-3.92-.43-8.52v0L8,13.31C5.37,14.12,1.2,15.39,1,15.5a.5.5,0,0,1-.21,0,.52.52,0,0,1-.49-.45,1,1,0,0,1,.52-1l1.74-.91c1.36-.71,3.22-1.69,4.66-2.43a4,4,0,0,1,0-.52c0-.69,0-1,0-1.14l.25-.13H7.16A1.07,1.07,0,0,1,8.24,7.73,1.12,1.12,0,0,1,9.06,8a1.46,1.46,0,0,1,.26.87L9.08,9h.25c0,.14,0,.31,0,.58l1.52-.84c0-1.48,0-7.06,1.1-8.25a.74.74,0,0,1,1.13,0c1.15,1.19,1.13,6.78,1.1,8.25l1.52.84c0-.32,0-.48,0-.58l.25-.13H15.7A1.46,1.46,0,0,1,16,8a1.11,1.11,0,0,1,.82-.28,1.06,1.06,0,0,1,1.08,1.16V9c0,.19,0,.48,0,1.17a4,4,0,0,1,0,.52c1.75.9,4.4,2.29,5.67,3l.73.38a.9.9,0,0,1,.5,1,.55.55,0,0,1-.5.47h0l-.11,0c-.28-.11-4.81-1.49-7.16-2.2H14.06v0c.09,4.6-.06,7.46-.43,8.52.52.33,2.07,1.29,3.2,2l.11.07L17,25.29l-.33-.09-3.33-.86c-.12.7-.6,1.41-.86,1.41h0Z"/><path class="cls-2" d="M12.51.5C13.93.5,14,7,13.93,8.91c.3.16,1.64.91,2,1.1,0-.6,0-.85,0-1s0-.09,0-.13a1.18,1.18,0,0,1,.19-.7A.88.88,0,0,1,16.78,8h0a.82.82,0,0,1,.83.91s0,.07,0,.13,0,.44,0,1.17a3.21,3.21,0,0,1-.06.66c2.33,1.19,6.51,3.39,6.56,3.42.59.3.4,1,.11,1h-.07c-.37-.14-7.18-2.21-7.18-2.21l-3.18,0c0,.22.22,7.56-.48,8.91,0,0,2,1.26,3.39,2.08l.06.93L13.15,24a2.14,2.14,0,0,1-.64,1.47A2.14,2.14,0,0,1,11.87,24L8.26,25,8.31,24c1.38-.82,3.39-2.08,3.39-2.08-.7-1.35-.48-8.69-.48-8.91L8,13.06S1.17,15.13.86,15.27l-.11,0c-.32,0-.43-.73.14-1S5.13,12,7.46,10.85a3.21,3.21,0,0,1-.06-.66c0-.73,0-1,0-1.17s0-.09,0-.13A.82.82,0,0,1,8.24,8h0a.88.88,0,0,1,.65.21,1.18,1.18,0,0,1,.19.7s0,.07,0,.13,0,.39,0,1c.36-.19,1.71-.94,2-1.1C11.05,7,11.09.5,12.51.5m0-.5a1,1,0,0,0-.74.34c-1.16,1.2-1.2,6.3-1.18,8.28L10,8.93l-.46.25V8.91a1.68,1.68,0,0,0-.33-1.06,1.34,1.34,0,0,0-1-.36,1.31,1.31,0,0,0-1.33,1.4V9h0v0c0,.16,0,.46,0,1.14,0,.13,0,.26,0,.38l-4.5,2.35-1.74.91A1.2,1.2,0,0,0,0,15.15a.77.77,0,0,0,.73.64.74.74,0,0,0,.31-.07c.29-.12,4.35-1.35,7-2.17l2.6,0c-.1,5.54.17,7.46.38,8.2-.64.4-2,1.25-3,1.86l-.22.13,0,.26-.06.93,0,.81.7-.31,3.06-.79c.19.67.63,1.35,1,1.35s.86-.68,1-1.35l3.06.79.7.31,0-.81L17.2,24l0-.26L17,23.6c-1-.61-2.4-1.47-3-1.86.21-.74.48-2.66.38-8.2l2.6,0c2.72.83,6.81,2.07,7.07,2.18a.68.68,0,0,0,.25,0,.79.79,0,0,0,.74-.67,1.15,1.15,0,0,0-.63-1.29l-.71-.37c-1.23-.65-3.78-2-5.53-2.88,0-.12,0-.25,0-.38,0-.67,0-1,0-1.14h0V8.92a1.32,1.32,0,0,0-1.32-1.44,1.35,1.35,0,0,0-1,.36,1.67,1.67,0,0,0-.33,1V9h0v.22L15,8.93l-.57-.32c0-2,0-7.08-1.18-8.28A1,1,0,0,0,12.51,0Z"/></g></g></svg>';
    var positions = [fromLonLat([-82.082750, 41.379850]), fromLonLat([-82.192046, 42.774613]), fromLonLat([-84.214880, 43.328549]), fromLonLat([-84.050620, 44.695230])];
    var startingTrack = -0.1
    var endingTrack = 0.1

    // Map tiles
    this.tileLayer = new TileLayer({
      source: new OSM()
    });

    // Flight data
    this.start = new Feature({
      geometry: new Point(fromLonLat([-82.082750, 41.379850]))
    });
    this.start.setStyle(new Style({
      image: new Icon(({
        opacity: 1,
        src: 'data:image/svg+xml;utf8,' + encodeURIComponent(airlinerSvg),
        rotation: startingTrack
      }))
    }));
    this.end = new Feature({
      geometry: new Point(fromLonLat([-84.050620, 44.695230]))
    });
    this.end.setStyle(new Style({
      image: new Icon(({
        opacity: 1,
        src: 'data:image/svg+xml;utf8,' + encodeURIComponent(airlinerSvg),
        rotation: endingTrack
      }))
    }));
    this.plot = new Feature({
      geometry: new LineString(positions)
    });
    this.vectorSource = new VectorSource({
      features: [this.start, this.end, this.plot]
    });
    this.vectorLayer = new VectorLayer({
      source: this.vectorSource
    });

    this.view = new View({
      center: fromLonLat([-82.082750, 41.379850]),
      zoom: 7,
      maxZoom: 18
    });
    this.map = new Map({
      layers: [this.tileLayer, this.vectorLayer],
      target: 'map',
      view: this.view 
    })

  }
}