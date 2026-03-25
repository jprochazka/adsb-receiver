#!/bin/bash

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
DOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

renice -n 5 -p $$

source "$(dirname "$0")/system-collectd-graphs.sh"

## DUMP1090 GRAPHS

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
  "DEF:all=$2/dump1090_aircraft-recent.rrd:total:AVERAGE" \
  "DEF:pos=$2/dump1090_aircraft-recent.rrd:positions:AVERAGE" \
  "DEF:mlat=$2/dump1090_mlat-recent.rrd:value:AVERAGE" \
  "CDEF:noloc=all,pos,-" \
  "VDEF:avgac=all,AVERAGE" \
  "VDEF:maxac=all,MAXIMUM" \
  "AREA:all#00FF00:Aircraft Seen / Tracked,   " \
  "GPRINT:avgac:Average\:%3.0lf     " \
  "GPRINT:maxac:Maximum\:%3.0lf             " \
  "LINE1:pos#0000FF:w/ Positions" \
  "LINE1:noloc#FF0000:w/o Positions" \
  "LINE1:mlat#000000:mlat" \
  --watermark "Drawn: $nowlit";
}

aircraft_message_rate_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 428 \
  --height 200 \
  --step "$5" \
  --title "$3 Message Rate / Aircraft" \
  --vertical-label "Messages/Aircraft/Second" \
  --right-axis-label "Aircraft" \
  --lower-limit 0 \
  --units-exponent 0 \
  --right-axis 10:0 \
  "TEXTALIGN:center" \
  "DEF:aircrafts=$2/dump1090_aircraft-recent.rrd:total:AVERAGE" \
  "DEF:messages=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE" \
  "CDEF:provisional=messages,aircrafts,/" \
  "CDEF:rate=aircrafts,0,GT,provisional,0,IF" \
  "CDEF:aircrafts10=aircrafts,10,/" \
  "VDEF:avgrate=rate,AVERAGE" \
  "VDEF:maxrate=rate,MAXIMUM" \
  "LINE1:rate#0000FF:Messages / AC" \
  "LINE1:avgrate#666666:Average:dashes" \
  "GPRINT:avgrate:%3.1lf" \
  "LINE1:maxrate#FF0000:Maximum" \
  "GPRINT:maxrate:%3.1lf\c" \
  "LINE1:aircrafts10#990000:Aircraft Seen / Tracked (RHS) \c" \
  --watermark "Drawn: $nowlit";
}

cpu_graph_dump1090() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 CPU Utilization" \
  --vertical-label "CPU %" \
  --lower-limit 0 \
  --rigid \
  "DEF:demod=$2/dump1090_cpu-demod.rrd:value:AVERAGE" \
  "CDEF:demodp=demod,10,/" \
  "DEF:reader=$2/dump1090_cpu-reader.rrd:value:AVERAGE" \
  "CDEF:readerp=reader,10,/" \
  "DEF:background=$2/dump1090_cpu-background.rrd:value:AVERAGE" \
  "CDEF:backgroundp=background,10,/" \
  "AREA:readerp#008000:USB" \
  "AREA:backgroundp#00C000:Other:STACK" \
  "AREA:demodp#00FF00:Demodulator\c:STACK" \
  "COMMENT: \n" \
  --watermark "Drawn: $nowlit";
}

tracks_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Tracks Seen" \
  --vertical-label "Tracks/Hour" \
  --lower-limit 0 \
  --units-exponent 0 \
  "DEF:all=$2/dump1090_tracks-all.rrd:value:AVERAGE" \
  "DEF:single=$2/dump1090_tracks-single_message.rrd:value:AVERAGE" \
  "CDEF:hall=all,3600,*" \
  "CDEF:hsingle=single,3600,*" \
  "AREA:hsingle#FF0000:Tracks with single message" \
  "AREA:hall#00FF00:Unique tracks\c:STACK" \
  "COMMENT: \n" \
  --watermark "Drawn: $nowlit";
}

## RECEIVER GRAPHS

local_rate_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 429 \
  --height 200 \
  --step "$5" \
  --title "$3 Message Rate" \
  --vertical-label "Messages/Second" \
  --lower-limit 0  \
  --units-exponent 0 \
  --right-axis 360:0 \
  "DEF:messages=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE" \
  "DEF:strong=$2/dump1090_messages-strong_signals.rrd:value:AVERAGE" \
  "DEF:positions=$2/dump1090_messages-positions.rrd:value:AVERAGE" \
  "CDEF:y2strong=strong,1.6666666666666,*" \
  "CDEF:y2positions=positions,10,*" \
  "LINE1:messages#0000FF:Messages Received" \
  "AREA:y2strong#FF0000:Messages > -3dBFS / 10min (RHS)" \
  "LINE1:y2positions#00c0FF:Positions / Hr (RHS)\c" \
  "COMMENT: \n" \
  --watermark "Drawn: $nowlit";
}

local_trailing_rate_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 959 \
  --height 200 \
  --step "$5" \
  --title "$3 Message Rate" \
  --vertical-label "Messages/Second" \
  --lower-limit 0  \
  --units-exponent 0 \
  --right-axis 360:0 \
  --slope-mode \
  --pango-markup \
  "TEXTALIGN:center" \
  "DEF:messages=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE" \
  "DEF:a=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE:end=now-86400:start=end-86400" \
  "DEF:b=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE:end=now-172800:start=end-86400" \
  "DEF:c=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE:end=now-259200:start=end-86400" \
  "DEF:d=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE:end=now-345600:start=end-86400" \
  "DEF:e=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE:end=now-432000:start=end-86400" \
  "DEF:f=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE:end=now-518400:start=end-86400" \
  "DEF:g=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE:end=now-604800:start=end-86400" \
  "DEF:amin=$2/dump1090_messages-local_accepted.rrd:value:MIN:end=now-86400:start=end-86400" \
  "DEF:bmin=$2/dump1090_messages-local_accepted.rrd:value:MIN:end=now-172800:start=end-86400" \
  "DEF:cmin=$2/dump1090_messages-local_accepted.rrd:value:MIN:end=now-259200:start=end-86400" \
  "DEF:dmin=$2/dump1090_messages-local_accepted.rrd:value:MIN:end=now-345600:start=end-86400" \
  "DEF:emin=$2/dump1090_messages-local_accepted.rrd:value:MIN:end=now-432000:start=end-86400" \
  "DEF:fmin=$2/dump1090_messages-local_accepted.rrd:value:MIN:end=now-518400:start=end-86400" \
  "DEF:gmin=$2/dump1090_messages-local_accepted.rrd:value:MIN:end=now-604800:start=end-86400" \
  "DEF:amax=$2/dump1090_messages-local_accepted.rrd:value:MAX:end=now-86400:start=end-86400" \
  "DEF:bmax=$2/dump1090_messages-local_accepted.rrd:value:MAX:end=now-172800:start=end-86400" \
  "DEF:cmax=$2/dump1090_messages-local_accepted.rrd:value:MAX:end=now-259200:start=end-86400" \
  "DEF:dmax=$2/dump1090_messages-local_accepted.rrd:value:MAX:end=now-345600:start=end-86400" \
  "DEF:emax=$2/dump1090_messages-local_accepted.rrd:value:MAX:end=now-432000:start=end-86400" \
  "DEF:fmax=$2/dump1090_messages-local_accepted.rrd:value:MAX:end=now-518400:start=end-86400" \
  "DEF:gmax=$2/dump1090_messages-local_accepted.rrd:value:MAX:end=now-604800:start=end-86400" \
  "CDEF:a1=a,UN,0,a,IF" \
  "CDEF:b1=b,UN,0,b,IF" \
  "CDEF:c1=c,UN,0,c,IF" \
  "CDEF:d1=d,UN,0,d,IF" \
  "CDEF:e1=e,UN,0,e,IF" \
  "CDEF:f1=f,UN,0,f,IF" \
  "CDEF:g1=g,UN,0,g,IF" \
  "CDEF:amin1=amin,UN,1000,amin,IF" \
  "CDEF:bmin1=bmin,UN,1000,bmin,IF" \
  "CDEF:cmin1=cmin,UN,1000,cmin,IF" \
  "CDEF:dmin1=dmin,UN,1000,dmin,IF" \
  "CDEF:emin1=emin,UN,1000,emin,IF" \
  "CDEF:fmin1=fmin,UN,1000,fmin,IF" \
  "CDEF:gmin1=gmin,UN,1000,gmin,IF" \
  "CDEF:amax1=amax,UN,0,amax,IF" \
  "CDEF:bmax1=bmax,UN,0,bmax,IF" \
  "CDEF:cmax1=cmax,UN,0,cmax,IF" \
  "CDEF:dmax1=dmax,UN,0,dmax,IF" \
  "CDEF:emax1=emax,UN,0,emax,IF" \
  "CDEF:fmax1=fmax,UN,0,fmax,IF" \
  "CDEF:gmax1=gmax,UN,0,gmax,IF" \
  "DEF:strong=$2/dump1090_messages-strong_signals.rrd:value:AVERAGE" \
  "DEF:positions=$2/dump1090_messages-positions.rrd:value:AVERAGE" \
  "CDEF:y2strong=strong,1.6666666666666,*" \
  "CDEF:y2positions=positions,10,*" \
  "VDEF:strong_total=strong,TOTAL" \
  "VDEF:messages_total=messages,TOTAL" \
  "CDEF:hundred=messages,UN,100,100,IF" \
  "CDEF:strong_percent=strong_total,hundred,*,messages_total,/" \
  "VDEF:strong_percent_vdef=strong_percent,LAST" \
  "SHIFT:a1:86400" \
  "SHIFT:b1:172800" \
  "SHIFT:c1:259200" \
  "SHIFT:d1:345600" \
  "SHIFT:e1:432000" \
  "SHIFT:f1:518400" \
  "SHIFT:g1:604800" \
  "SHIFT:amin1:86400" \
  "SHIFT:bmin1:172800" \
  "SHIFT:cmin1:259200" \
  "SHIFT:dmin1:345600" \
  "SHIFT:emin1:432000" \
  "SHIFT:fmin1:518400" \
  "SHIFT:gmin1:604800" \
  "SHIFT:amax1:86400" \
  "SHIFT:bmax1:172800" \
  "SHIFT:cmax1:259200" \
  "SHIFT:dmax1:345600" \
  "SHIFT:emax1:432000" \
  "SHIFT:fmax1:518400" \
  "SHIFT:gmax1:604800" \
  "CDEF:7dayaverage=a1,b1,c1,d1,e1,f1,g1,+,+,+,+,+,+,7,/" \
  "CDEF:min1=amin1,bmin1,MIN" \
  "CDEF:min2=cmin1,dmin1,MIN" \
  "CDEF:min3=emin1,fmin1,MIN" \
  "CDEF:min4=min1,min2,MIN" \
  "CDEF:min5=min3,gmin1,MIN" \
  "CDEF:min=min4,min5,MIN" \
  "CDEF:max1=amax1,bmax1,MAX" \
  "CDEF:max2=cmax1,dmax1,MAX" \
  "CDEF:max3=emax1,fmax1,MAX" \
  "CDEF:max4=max1,max2,MAX" \
  "CDEF:max5=max3,gmax1,MAX" \
  "CDEF:max=max4,max5,MAX" \
  "CDEF:maxarea=max,min,-" \
  "LINE1:messages#0000FF:Messages Received" \
  "LINE1:min#FFFF99" \
  "AREA:maxarea#FFFF99:Min/Max:STACK" \
  "LINE1:7dayaverage#00FF00:7 Day Average" \
  "LINE1:messages#0000FF" \
  "AREA:y2strong#FF0000:Messages > -3dBFS/10min (RHS)\g" \
  "GPRINT:strong_percent_vdef: (%1.1lf<span font='2'> </span>%% of messages)" \
  "LINE1:y2positions#00c0FF:Positions/Hr (RHS)\c" \
  --watermark "Drawn: $nowlit";
}

range_graph_imperial_nautical(){
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
  "DEF:rangem=$2/dump1090_range-max_range.rrd:value:MAX" \
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

range_graph_imperial_statute(){
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
  "DEF:rangem=$2/dump1090_range-max_range.rrd:value:MAX" \
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
  "DEF:rangem=$2/dump1090_range-max_range.rrd:value:MAX" \
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

signal_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 186 \
  --step "$5" \
  --title "$3 Signal Level" \
  --vertical-label "dBFS" \
  --upper-limit 1    \
  --lower-limit -45 \
  --rigid \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:signal=$2/dump1090_dbfs-signal.rrd:value:AVERAGE" \
  "DEF:peak=$2/dump1090_dbfs-peak_signal.rrd:value:AVERAGE" \
  "DEF:minsig=$2/dump1090_dbfs-min_signal.rrd:value:AVERAGE" \
  "DEF:noise=$2/dump1090_dbfs-noise.rrd:value:AVERAGE" \
  "CDEF:us=signal,UN,-100,signal,IF" \
  "AREA:-100#00FF00:Mean Level\\:" \
  "AREA:us#FFFFFF" \
  "GPRINT:signal:AVERAGE:%4.1lf" \
  "LINE1:peak#0000FF:Peak Level\:" \
  "GPRINT:peak:MAX:%4.1lf\c" \
  "LINE1:minsig#00AAFF:Min Level\:" \
  "GPRINT:minsig:MIN:%4.1lf\c" \
  "LINE:noise#7F00FF:Noise" \
  "GPRINT:noise:MAX:Max\: %4.1lf" \
  "GPRINT:noise:MIN:Min\: %4.1lf" \
  "GPRINT:noise:AVERAGE:Avg\: %4.1lf\c" \
  "LINE1:0#000000:Zero dBFS" \
  "LINE1:-3#FF0000:-3 dBFS\c" \
  --watermark "Drawn: $nowlit";
}

positions_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Positions Decoded" \
  --vertical-label "Positions/Hour" \
  --lower-limit 0 \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:pos=$2/dump1090_messages-positions.rrd:value:AVERAGE" \
  "CDEF:poshr=pos,3600,*" \
  "VDEF:avgpos=poshr,AVERAGE" \
  "VDEF:maxpos=poshr,MAXIMUM" \
  "AREA:poshr#00AAFF:Positions/Hour" \
  "GPRINT:avgpos:Average\:%6.0lf/hr     " \
  "GPRINT:maxpos:Maximum\:%6.0lf/hr\c" \
  --watermark "Drawn: $nowlit";
}

strong_signals_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 429 \
  --height 200 \
  --step "$5" \
  --title "$3 Strong Signals (>-3 dBFS)" \
  --vertical-label "% of Messages" \
  --lower-limit 0 \
  --upper-limit 100 \
  --rigid \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:strong=$2/dump1090_messages-strong_signals.rrd:value:AVERAGE" \
  "DEF:total=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE" \
  "CDEF:pct=total,0,GT,strong,100,*,total,/,0,IF" \
  "VDEF:avgpct=pct,AVERAGE" \
  "VDEF:maxpct=pct,MAXIMUM" \
  "AREA:pct#FF4444:Strong Messages %" \
  "LINE1:5#FF0000:5%% Warn\::dashes" \
  "GPRINT:avgpct:Average\:%4.1lf%%     " \
  "GPRINT:maxpct:Maximum\:%4.1lf%%\c" \
  --watermark "Drawn: $nowlit";
}

df_types_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 1010 \
  --height 200 \
  --step "$5" \
  --title "$3 Message Types" \
  --vertical-label "Messages/Second" \
  --lower-limit 0 \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:df17=$2/dump1090_messages-local_accepted_17.rrd:value:AVERAGE" \
  "DEF:df18=$2/dump1090_messages-local_accepted_18.rrd:value:AVERAGE" \
  "DEF:df11=$2/dump1090_messages-local_accepted_11.rrd:value:AVERAGE" \
  "DEF:df4=$2/dump1090_messages-local_accepted_4.rrd:value:AVERAGE" \
  "DEF:df5=$2/dump1090_messages-local_accepted_5.rrd:value:AVERAGE" \
  "DEF:df20=$2/dump1090_messages-local_accepted_20.rrd:value:AVERAGE" \
  "DEF:df21=$2/dump1090_messages-local_accepted_21.rrd:value:AVERAGE" \
  "DEF:total=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE" \
  "CDEF:surv=df4,df5,+" \
  "CDEF:commD=df20,df21,+" \
  "CDEF:known=df17,df18,df11,surv,commD,+,+,+,+" \
  "CDEF:other=total,known,-,0,MAX" \
  "AREA:df17#0080FF:DF17 ADS-B ES      " \
  "AREA:df18#00DDFF:DF18 TIS-B ES:STACK" \
  "AREA:df11#00FF80:DF11 All-Call:STACK" \
  "AREA:surv#80FF00:DF4/5 Surv.:STACK" \
  "AREA:commD#FFFF00:DF20/21 Comm-D:STACK" \
  "AREA:other#FF8000:Other:STACK" \
  --watermark "Drawn: $nowlit";
}

## HUB GRAPHS

remote_rate_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Message Rate" \
  --vertical-label "messages/second" \
  --lower-limit 0  \
  --units-exponent 0 \
  --right-axis 360:0 \
  "DEF:messages=$2/dump1090_messages-remote_accepted.rrd:value:AVERAGE" \
  "DEF:positions=$2/dump1090_messages-positions.rrd:value:AVERAGE" \
  "CDEF:y2positions=positions,10,*" \
  "LINE1:messages#0000FF:messages received" \
  "LINE1:y2positions#00c0FF:position / hr (RHS)" \
  --watermark "Drawn: $nowlit";
}


dump1090_graphs() {
  aircraft_graph ${DOCUMENTROOT}/graphs/dump1090-$2-aircraft-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  aircraft_message_rate_graph ${DOCUMENTROOT}/graphs/dump1090-$2-aircraft_message_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  cpu_graph_dump1090 ${DOCUMENTROOT}/graphs/dump1090-$2-cpu-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  tracks_graph ${DOCUMENTROOT}/graphs/dump1090-$2-tracks-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5" 
}

dump1090_receiver_graphs() {
  dump1090_graphs "$1" "$2" "$3" "$4" "$5"
  system_graphs "$1" "$2" "$3" "$4" "$5"
  local_rate_graph ${DOCUMENTROOT}/graphs/dump1090-$2-local_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  local_trailing_rate_graph ${DOCUMENTROOT}/graphs/dump1090-$2-local_trailing_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  range_graph_imperial_nautical ${DOCUMENTROOT}/graphs/dump1090-$2-range_imperial_nautical-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  range_graph_imperial_statute ${DOCUMENTROOT}/graphs/dump1090-$2-range_imperial_statute-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  range_graph_metric ${DOCUMENTROOT}/graphs/dump1090-$2-range_metric-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  signal_graph ${DOCUMENTROOT}/graphs/dump1090-$2-signal-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  positions_graph ${DOCUMENTROOT}/graphs/dump1090-$2-positions-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  strong_signals_graph ${DOCUMENTROOT}/graphs/dump1090-$2-strong_signals-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  df_types_graph ${DOCUMENTROOT}/graphs/dump1090-$2-df_types-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
}

dump1090_hub_graphs() {
  dump1090_graphs "$1" "$2" "$3" "$4" "$5"
  system_graphs "$1" "$2" "$3" "$4" "$5"
  remote_rate_graph ${DOCUMENTROOT}/graphs/dump1090-$2-remote_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
}

period="$1"
step="$2"
nowlit=`date '+%m/%d/%y %H:%M %Z'`;

dump1090_receiver_graphs localhost localhost "ADS-B" "$period" "$step"
#hub_graphs localhost rpi "ADS-B" "$period" "$step"
