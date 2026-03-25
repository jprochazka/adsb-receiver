#!/bin/bash

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
DOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

renice -n 5 -p $$

source "$(dirname "$0")/system-collectd-graphs.sh"

## DUMP978 GRAPHS
#
# dump978 does not produce stats.json, so there are no message rate, CPU,
# tracks, or signal graphs. Only aircraft counts and max range are available.
# MLAT is also not supported by the UAT decoder.

aircraft_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Aircraft Seen / Tracked" \
  --vertical-label "Aircraft" \
  --lower-limit 0 \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:all=$2/dump978_aircraft-recent.rrd:total:AVERAGE" \
  "DEF:pos=$2/dump978_aircraft-recent.rrd:positions:AVERAGE" \
  "DEF:cs=$2/dump978_aircraft-recent.rrd:with_callsign:AVERAGE" \
  "CDEF:noloc=all,pos,-" \
  "VDEF:avgac=all,AVERAGE" \
  "VDEF:maxac=all,MAXIMUM" \
  "AREA:all#00FF00:Aircraft Seen / Tracked,   " \
  "GPRINT:avgac:Average\:%3.0lf     " \
  "GPRINT:maxac:Maximum\:%3.0lf             " \
  "LINE1:pos#0000FF:w/ Positions" \
  "LINE1:noloc#FF0000:w/o Positions" \
  "LINE1:cs#FF8800:w/ Callsign" \
  --watermark "Drawn: $nowlit";
}

signal_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Signal Strength" \
  --vertical-label "dBFS" \
  --upper-limit 0 \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:signal=$2/dump978_dbfs-signal.rrd:value:AVERAGE" \
  "VDEF:avgsig=signal,AVERAGE" \
  "VDEF:maxsig=signal,MAXIMUM" \
  "VDEF:minsig=signal,MINIMUM" \
  "LINE1:signal#0000FF:Avg Signal (dBFS)" \
  "GPRINT:avgsig:Average\:%4.1lf dBFS     " \
  "GPRINT:maxsig:Peak\:%4.1lf dBFS     " \
  "GPRINT:minsig:Min\:%4.1lf dBFS\c" \
  --watermark "Drawn: $nowlit";
}

message_rate_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 1010 \
  --height 200 \
  --step "$5" \
  --title "$3 Message Rate" \
  --vertical-label "Messages/sec" \
  --lower-limit 0 \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:msgs=$2/dump978_messages-messages.rrd:value:AVERAGE" \
  "VDEF:avgmsg=msgs,AVERAGE" \
  "VDEF:maxmsg=msgs,MAXIMUM" \
  "AREA:msgs#00AA00:Messages/sec" \
  "GPRINT:avgmsg:Average\:%4.1lf/sec     " \
  "GPRINT:maxmsg:Maximum\:%4.1lf/sec\c" \
  --watermark "Drawn: $nowlit";
}

altitude_graph_imperial() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Avg Aircraft Altitude" \
  --vertical-label "Feet" \
  --lower-limit 0 \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:alt=$2/dump978_altitude-average.rrd:value:AVERAGE" \
  "VDEF:avgalt=alt,AVERAGE" \
  "VDEF:maxalt=alt,MAXIMUM" \
  "LINE1:alt#AA00AA:Avg Altitude (ft)" \
  "GPRINT:avgalt:Average\:%5.0lf ft     " \
  "GPRINT:maxalt:Maximum\:%5.0lf ft\c" \
  --watermark "Drawn: $nowlit";
}

altitude_graph_metric() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Avg Aircraft Altitude" \
  --vertical-label "Metres" \
  --lower-limit 0 \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:altft=$2/dump978_altitude-average.rrd:value:AVERAGE" \
  "CDEF:altm=altft,0.3048,*" \
  "VDEF:avgaltm=altm,AVERAGE" \
  "VDEF:maxaltm=altm,MAXIMUM" \
  "LINE1:altm#AA00AA:Avg Altitude (m)" \
  "GPRINT:avgaltm:Average\:%5.0lf m     " \
  "GPRINT:maxaltm:Maximum\:%5.0lf m\c" \
  --watermark "Drawn: $nowlit";
}

range_graph_imperial_nautical() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 428 \
  --height 200 \
  --step "$5" \
  --title "$3 Max Range" \
  --vertical-label "Nautical Miles" \
  --units-exponent 0 \
  --right-axis 1.852:0 \
  --right-axis-label "Kilometres" \
  "DEF:rangem=$2/dump978_range-max_range.rrd:value:MAX" \
  "CDEF:rangekm=rangem,0.001,*" \
  "CDEF:rangenm=rangekm,0.539956803,*" \
  "LINE1:rangenm#0000FF:Max Range" \
  "VDEF:avgrange=rangenm,AVERAGE" \
  "LINE1:avgrange#666666:Avr Range\\::dashes" \
  "VDEF:peakrange=rangenm,MAXIMUM" \
  "GPRINT:avgrange:%1.1lf NM" \
  "LINE1:peakrange#FF0000:Peak Range\\:" \
  "GPRINT:peakrange:%1.1lf NM\c" \
  "COMMENT: \n" \
  --watermark "Drawn: $nowlit";
}

range_graph_imperial_statute() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 428 \
  --height 200 \
  --step "$5" \
  --title "$3 Max Range" \
  --vertical-label "Statute Miles" \
  --units-exponent 0 \
  --right-axis 1.609:0 \
  --right-axis-label "Kilometres" \
  "DEF:rangem=$2/dump978_range-max_range.rrd:value:MAX" \
  "CDEF:rangekm=rangem,0.001,*" \
  "CDEF:rangesm=rangekm,0.621371,*" \
  "LINE1:rangesm#0000FF:Max Range" \
  "VDEF:avgrange=rangesm,AVERAGE" \
  "LINE1:avgrange#666666:Avr Range\\::dashes" \
  "VDEF:peakrange=rangesm,MAXIMUM" \
  "GPRINT:avgrange:%1.1lf SM" \
  "LINE1:peakrange#FF0000:Peak Range\\:" \
  "GPRINT:peakrange:%1.1lf SM\c" \
  "COMMENT: \n" \
  --watermark "Drawn: $nowlit";
}

range_graph_metric() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 428 \
  --height 200 \
  --step "$5" \
  --title "$3 Max Range" \
  --vertical-label "Kilometres" \
  --units-exponent 0 \
  --right-axis 0.5399:0 \
  --right-axis-label "Nautical Miles" \
  "DEF:rangem=$2/dump978_range-max_range.rrd:value:MAX" \
  "CDEF:range=rangem,0.001,*" \
  "LINE1:range#0000FF:Max Range" \
  "VDEF:avgrange=range,AVERAGE" \
  "LINE1:avgrange#666666:Avg Range\\::dashes" \
  "VDEF:peakrange=range,MAXIMUM" \
  "GPRINT:avgrange:%1.1lf km" \
  "LINE1:peakrange#FF0000:Peak Range\\:" \
  "GPRINT:peakrange:%1.1lf km\c" \
  "COMMENT: \n" \
  --watermark "Drawn: $nowlit";
}

dump978_graphs() {
  aircraft_graph ${DOCUMENTROOT}/graphs/dump978-$2-aircraft-$4.png /var/lib/collectd/rrd/$1/dump978-$2 "$3" "$4" "$5"
  range_graph_imperial_nautical ${DOCUMENTROOT}/graphs/dump978-$2-range_imperial_nautical-$4.png /var/lib/collectd/rrd/$1/dump978-$2 "$3" "$4" "$5"
  range_graph_imperial_statute ${DOCUMENTROOT}/graphs/dump978-$2-range_imperial_statute-$4.png /var/lib/collectd/rrd/$1/dump978-$2 "$3" "$4" "$5"
  range_graph_metric ${DOCUMENTROOT}/graphs/dump978-$2-range_metric-$4.png /var/lib/collectd/rrd/$1/dump978-$2 "$3" "$4" "$5"
  signal_graph ${DOCUMENTROOT}/graphs/dump978-$2-signal-$4.png /var/lib/collectd/rrd/$1/dump978-$2 "$3" "$4" "$5"
  message_rate_graph ${DOCUMENTROOT}/graphs/dump978-$2-message_rate-$4.png /var/lib/collectd/rrd/$1/dump978-$2 "$3" "$4" "$5"
  altitude_graph_imperial ${DOCUMENTROOT}/graphs/dump978-$2-altitude_imperial-$4.png /var/lib/collectd/rrd/$1/dump978-$2 "$3" "$4" "$5"
  altitude_graph_metric ${DOCUMENTROOT}/graphs/dump978-$2-altitude_metric-$4.png /var/lib/collectd/rrd/$1/dump978-$2 "$3" "$4" "$5"
}

dump978_receiver_graphs() {
  dump978_graphs "$1" "$2" "$3" "$4" "$5"
  system_graphs "$1" "$2" "$3" "$4" "$5"
}

period="$1"
step="$2"
nowlit=`date '+%m/%d/%y %H:%M %Z'`;

dump978_receiver_graphs localhost localhost "UAT" "$period" "$step"
