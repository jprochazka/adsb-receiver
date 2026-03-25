# Copyright (c) 2015, Oliver Jowett <oliver@mutability.co.uk>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# Adapted by Joseph Prochazka for FlightAware dump978-fa (978 MHz UAT decoder).
# dump978 produces only receiver.json and aircraft.json — there is no stats.json 
# and no MLAT support, so those sections from dump1090.py are omitted here.
#
# This plugin requires dump978.db to be registered in collectd.conf:
#   TypesDB "/path/to/dump978.db"

import collectd
import json, math
from contextlib import closing
from urllib.request import urlopen
from urllib.error import URLError
from urllib.parse import urlparse
import time

def handle_config(root):
    for child in root.children:
        instance_name = None

        if child.key == 'Instance':
            instance_name = child.values[0]
            url = None
            for ch2 in child.children:
                if ch2.key == 'URL':
                    url = ch2.values[0]
            if not url:
                collectd.warning('No URL found in dump978 Instance ' + instance_name)
            else:
                collectd.register_read(callback=handle_read,
                                       data=(instance_name, urlparse(url).hostname, url),
                                       name='dump978.' + instance_name)

        else:
            collectd.warning('Ignored config entry: ' + child.key)

V = collectd.Values(host='', plugin='dump978', time=0)

def T(provisional):
    now = time.time()
    if provisional <= now + 60: return provisional
    else: return now

def handle_read(data):
    instance_name, host, url = data
    read_aircraft(instance_name, host, url)

def greatcircle(lat0, lon0, lat1, lon1):
    lat0 = lat0 * math.pi / 180.0
    lon0 = lon0 * math.pi / 180.0
    lat1 = lat1 * math.pi / 180.0
    lon1 = lon1 * math.pi / 180.0
    return 6371e3 * math.acos(math.sin(lat0) * math.sin(lat1) + math.cos(lat0) * math.cos(lat1) * math.cos(abs(lon0 - lon1)))

def read_aircraft(instance_name, host, url):
    try:
        with closing(urlopen(url + '/data/receiver.json', None, 5.0)) as receiver_file:
            receiver = json.load(receiver_file)

        if 'lat' in receiver:
            rlat = float(receiver['lat'])
            rlon = float(receiver['lon'])
        else:
            rlat = rlon = None

        with closing(urlopen(url + '/data/aircraft.json', None, 5.0)) as aircraft_file:
            aircraft_data = json.load(aircraft_file)

    except URLError:
        return

    total = 0
    with_pos = 0
    with_callsign = 0
    max_range = 0
    total_messages = 0
    rssi_values = []
    alt_values = []

    for a in aircraft_data['aircraft']:
        if a['seen'] < 60:
            total += 1
            if 'flight' in a and a['flight'].strip():
                with_callsign += 1
            if 'rssi' in a:
                rssi_values.append(a['rssi'])
            if 'messages' in a:
                total_messages += a['messages']
        if 'seen_pos' in a and a['seen_pos'] < 60:
            with_pos += 1
            if rlat is not None:
                distance = greatcircle(rlat, rlon, a['lat'], a['lon'])
                if distance > max_range: max_range = distance
            if 'altitude' in a and isinstance(a['altitude'], (int, float)):
                alt_values.append(a['altitude'])

    V.dispatch(plugin_instance=instance_name,
               host=host,
               type='dump978_aircraft',
               type_instance='recent',
               time=T(aircraft_data['now']),
               values=[total, with_pos, with_callsign])

    if max_range > 0:
        V.dispatch(plugin_instance=instance_name,
                   host=host,
                   type='dump978_range',
                   type_instance='max_range',
                   time=T(aircraft_data['now']),
                   values=[max_range])

    if rssi_values:
        avg_rssi = sum(rssi_values) / len(rssi_values)
        V.dispatch(plugin_instance=instance_name,
                   host=host,
                   type='dump978_dbfs',
                   type_instance='signal',
                   time=T(aircraft_data['now']),
                   values=[avg_rssi])

    V.dispatch(plugin_instance=instance_name,
               host=host,
               type='dump978_messages',
               type_instance='messages',
               time=T(aircraft_data['now']),
               values=[total_messages])

    if alt_values:
        avg_alt = sum(alt_values) / len(alt_values)
        V.dispatch(plugin_instance=instance_name,
                   host=host,
                   type='dump978_altitude',
                   type_instance='average',
                   time=T(aircraft_data['now']),
                   values=[avg_alt])


collectd.register_config(callback=handle_config, name='dump978')
