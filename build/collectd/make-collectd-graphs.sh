#!/bin/sh

renice -n 5 -p $$

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
  --upper-limit 100 \
  --rigid \
  "DEF:demod=$2/dump1090_cpu-demod.rrd:value:AVERAGE" \
  "CDEF:demodp=demod,10,/" \
  "DEF:reader=$2/dump1090_cpu-reader.rrd:value:AVERAGE" \
  "CDEF:readerp=reader,10,/" \
  "DEF:background=$2/dump1090_cpu-background.rrd:value:AVERAGE" \
  "CDEF:backgroundp=background,10,/" \
  "AREA:readerp#008000:USB" \
  "AREA:backgroundp#00C000:other:STACK" \
  "AREA:demodp#00FF00:demodulator:STACK" \
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
  --vertical-label "tracks/hour" \
  --lower-limit 0 \
  --units-exponent 0 \
  "DEF:all=$2/dump1090_tracks-all.rrd:value:AVERAGE" \
  "DEF:single=$2/dump1090_tracks-single_message.rrd:value:AVERAGE" \
  "CDEF:hall=all,3600,*" \
  "CDEF:hsingle=single,3600,*" \
  "AREA:hsingle#FF0000:tracks with single message" \
  "AREA:hall#00FF00:unique tracks:STACK" \
  --watermark "Drawn: $nowlit";
}

## SYSTEM GRAPHS

cpu_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 1110 \
  --height 200 \
  --step "$5" \
  --title "Overall CPU Utilization" \
  --vertical-label "CPU / %" \
  --lower-limit 0 \
  --upper-limit 100 \
  --rigid \
  --units-exponent 0 \
  "DEF:idle=$2/cpu-idle.rrd:value:AVERAGE" \
  "DEF:interrupt=$2/cpu-interrupt.rrd:value:AVERAGE" \
  "DEF:nice=$2/cpu-nice.rrd:value:AVERAGE" \
  "DEF:softirq=$2/cpu-softirq.rrd:value:AVERAGE" \
  "DEF:steal=$2/cpu-steal.rrd:value:AVERAGE" \
  "DEF:system=$2/cpu-system.rrd:value:AVERAGE" \
  "DEF:user=$2/cpu-user.rrd:value:AVERAGE" \
  "DEF:wait=$2/cpu-wait.rrd:value:AVERAGE" \
  "CDEF:all=idle,interrupt,nice,softirq,steal,system,user,wait,+,+,+,+,+,+,+" \
  "CDEF:pinterrupt=100,interrupt,*,all,/" \
  "CDEF:pnice=100,nice,*,all,/" \
  "CDEF:psoftirq=100,softirq,*,all,/" \
  "CDEF:psteal=100,steal,*,all,/" \
  "CDEF:psystem=100,system,*,all,/" \
  "CDEF:puser=100,user,*,all,/" \
  "CDEF:pwait=100,wait,*,all,/" \
  "AREA:pinterrupt#000080:irq" \
  "AREA:psoftirq#0000C0:softirq:STACK" \
  "AREA:psteal#0000FF::STACK" \
  "AREA:pwait#C00000:io:STACK" \
  "AREA:psystem#FF0000:sys:STACK" \
  "AREA:puser#40FF40:user:STACK" \
  "AREA:pnice#008000:nice:STACK" \
  --watermark "Drawn: $nowlit";
}

df_root_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "Disk Usage (/)" \
  --vertical-label "" \
  --lower-limit 0  \
  "TEXTALIGN:center" \
  "DEF:used=$2/df_complex-used.rrd:value:AVERAGE" \
  "DEF:reserved=$2/df_complex-reserved.rrd:value:AVERAGE" \
  "DEF:free=$2/df_complex-free.rrd:value:AVERAGE" \
  "CDEF:totalused=used,reserved,+" \
  "AREA:totalused#4169E1:used:STACK" \
  "AREA:free#32C734:free:STACK" \
  --watermark "Drawn: $nowlit";
}

disk_io_iops_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "Disk I/O - IOPS" \
  --vertical-label "IOPS" \
  "TEXTALIGN:center" \
  "DEF:read=$2/disk_ops.rrd:read:AVERAGE" \
  "DEF:write=$2/disk_ops.rrd:write:AVERAGE" \
  "CDEF:write_neg=write,-1,*" \
  "AREA:read#32CD32:Reads " \
  "LINE1:read#336600" \
  "GPRINT:read:MAX:Max\:%4.1lf iops" \
  "GPRINT:read:AVERAGE:Avg\:%4.1lf iops" \
  "GPRINT:read:LAST:Current\:%4.1lf iops\c" \
  "TEXTALIGN:center" \
  "AREA:write_neg#4169E1:Writes" \
  "LINE1:write_neg#0033CC" \
  "GPRINT:write:MAX:Max\:%4.1lf iops" \
  "GPRINT:write:AVERAGE:Avg\:%4.1lf iops" \
  "GPRINT:write:LAST:Current\:%4.1lf iops\c" \
  "HRULE:0#000000" \
  --watermark "Drawn: $nowlit";
}

disk_io_octets_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "Disk I/O - Bandwidth" \
  --vertical-label "Bytes/s" \
  "TEXTALIGN:center" \
  "DEF:read=$2/disk_octets.rrd:read:AVERAGE" \
  "DEF:write=$2/disk_octets.rrd:write:AVERAGE" \
  "CDEF:write_neg=write,-1,*" \
  "AREA:read#32CD32:Reads " \
  "LINE1:read#336600" \
  "GPRINT:read:MAX:Max\: %4.1lf %sB/sec" \
  "GPRINT:read:AVERAGE:Avg\: %4.1lf %SB/sec" \
  "GPRINT:read:LAST:Current\: %4.1lf %SB/sec\c" \
  "TEXTALIGN:center" \
  "AREA:write_neg#4169E1:Writes" \
  "LINE1:write_neg#0033CC" \
  "GPRINT:write:MAX:Max\: %4.1lf %sB/sec" \
  "GPRINT:write:AVERAGE:Avg\: %4.1lf %SB/sec" \
  "GPRINT:write:LAST:Current\: %4.1lf %SB/sec\c" \
  "HRULE:0#000000" \
  --watermark "Drawn: $nowlit";
}

memory_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "Memory Utilization" \
  --vertical-label "" \
  "TEXTALIGN:center" \
  "DEF:buffered=$2/memory-buffered.rrd:value:AVERAGE" \
  "DEF:cached=$2/memory-cached.rrd:value:AVERAGE" \
  "DEF:free=$2/memory-free.rrd:value:AVERAGE" \
  "DEF:used=$2/memory-used.rrd:value:AVERAGE" \
  "AREA:used#4169E1:used:STACK" \
  "AREA:buffered#32C734:buffered:STACK" \
  "AREA:cached#00FF00:cached:STACK" \
  "AREA:free#FFFFFF:free:STACK" \
  --watermark "Drawn: $nowlit";
}

temp_graph_imperial() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "Core Temperature" \
  --vertical-label "Degrees Fahrenheit" \
  --lower-limit 32 \
  --upper-limit 212 \
  --rigid \
  --units-exponent 1 \
  "DEF:traw=$2/gauge-cpu_temp.rrd:value:MAX" \
  "CDEF:tta=traw,1000,/" \
  "CDEF:ttb=tta,1.8,*" \
  "CDEF:ttc=ttb,32,+" \
  "AREA:ttc#ffcc00" \
  --watermark "Drawn: $nowlit";
}

temp_graph_metric() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "Core Temperature" \
  --vertical-label "Degrees Celcius" \
  --lower-limit 0 \
  --upper-limit 100 \
  --rigid \
  --units-exponent 1 \
  "DEF:traw=$2/gauge-cpu_temp.rrd:value:MAX" \
  "CDEF:tfin=traw,1000,/" \
  "AREA:tfin#ffcc00" \
  --watermark "Drawn: $nowlit";
}

wlan0_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "Bandwidth Usage (wlan0)" \
  --vertical-label "bytes/sec" \
  "TEXTALIGN:center" \
  "DEF:rx=$2/if_octets.rrd:rx:AVERAGE" \
  "DEF:tx=$2/if_octets.rrd:tx:AVERAGE" \
  "CDEF:tx_neg=tx,-1,*" \
  "AREA:rx#32CD32:Incoming" \
  "LINE1:rx#336600" \
  "GPRINT:rx:MAX:Max\:%8.1lf %s" \
  "GPRINT:rx:AVERAGE:Avg\:%8.1lf %S" \
  "GPRINT:rx:LAST:Current\:%8.1lf %Sbytes/sec\n" \
  "AREA:tx_neg#4169E1:Outgoing" \
  "LINE1:tx_neg#0033CC" \
  "GPRINT:tx:MAX:Max\:%8.1lf %S" \
  "GPRINT:tx:AVERAGE:Avg\:%8.1lf %S" \
  "GPRINT:tx:LAST:Current\:%8.1lf %Sbytes/sec\n" \
  "HRULE:0#000000" \
  --watermark "Drawn: $nowlit";
}

## RECEIVER GRAPHS

local_rate_graph() {
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
  "DEF:messages=$2/dump1090_messages-local_accepted.rrd:value:AVERAGE" \
  "DEF:strong=$2/dump1090_messages-strong_signals.rrd:value:AVERAGE" \
  "DEF:positions=$2/dump1090_messages-positions.rrd:value:AVERAGE" \
  "CDEF:y2strong=strong,10,*" \
  "CDEF:y2positions=positions,10,*" \
  "LINE1:messages#0000FF:messages received" \
  "AREA:y2strong#FF0000:messages >-3dBFS / hr (RHS)" \
  "LINE1:y2positions#00c0FF:positions / hr (RHS)" \
  --watermark "Drawn: $nowlit";
}

local_trailing_rate_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 1110 \
  --height 200 \
  --step "$5" \
  --title "$3 Message Rate (Trailing)" \
  --vertical-label "messages/second" \
  --lower-limit 0  \
  --units-exponent 0 \
  --right-axis 360:0 \
  --slope-mode \
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
  "DEF:strong=$2/dump1090_messages-strong_signals.rrd:value:AVERAGE" \
  "DEF:positions=$2/dump1090_messages-positions.rrd:value:AVERAGE" \
  "CDEF:y2strong=strong,10,*" \
  "CDEF:y2positions=positions,10,*" \
  "SHIFT:a:86400" \
  "SHIFT:b:172800" \
  "SHIFT:c:259200" \
  "SHIFT:d:345600" \
  "SHIFT:e:432000" \
  "SHIFT:f:518400" \
  "SHIFT:g:604800" \
  "SHIFT:amin:86400" \
  "SHIFT:bmin:172800" \
  "SHIFT:cmin:259200" \
  "SHIFT:dmin:345600" \
  "SHIFT:emin:432000" \
  "SHIFT:fmin:518400" \
  "SHIFT:gmin:604800" \
  "SHIFT:amax:86400" \
  "SHIFT:bmax:172800" \
  "SHIFT:cmax:259200" \
  "SHIFT:dmax:345600" \
  "SHIFT:emax:432000" \
  "SHIFT:fmax:518400" \
  "SHIFT:gmax:604800" \
  "CDEF:7dayaverage=a,b,c,d,e,f,g,+,+,+,+,+,+,7,/" \
  "CDEF:min1=amin,bmin,MIN" \
  "CDEF:min2=cmin,dmin,MIN" \
  "CDEF:min3=emin,fmin,MIN" \
  "CDEF:min4=min1,min2,MIN" \
  "CDEF:min5=min3,gmin,MIN" \
  "CDEF:min=min4,min5,MIN" \
  "CDEF:max1=amax,bmax,MAX" \
  "CDEF:max2=cmax,dmax,MAX" \
  "CDEF:max3=emax,fmax,MAX" \
  "CDEF:max4=max1,max2,MAX" \
  "CDEF:max5=max3,gmax,MAX" \
  "CDEF:max=max4,max5,MAX" \
  "CDEF:maxarea=max,min,-" \
  "LINE1:min#FFFF99:mins" \
  "AREA:maxarea#FFFF99:max:STACK" \
  "LINE1:7dayaverage#00FF00:7 day average" \
  "AREA:y2strong#FF0000:messages >-3dBFS / hr (RHS)" \
  "LINE1:y2positions#00c0FF:positions / hr (RHS)" \
  "LINE1:messages#0000FF:messages received" \
  --watermark "Drawn: $nowlit";
}

range_graph_imperial(){
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Max Range" \
  --vertical-label "miles" \
  --lower-limit 0 \
  --units-exponent 0 \
  "DEF:rangem=$2/dump1090_range-max_range.rrd:value:MAX" \
  "CDEF:rangekm=rangem,1000,/" \
  "CDEF:rangeml=rangekm,0.621371192,*" \
  "LINE1:rangeml#0000FF:max range" \
  --watermark "Drawn: $nowlit";
}

range_graph_metric() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Max Range" \
  --vertical-label "kilometers" \
  --lower-limit 0 \
  --units-exponent 0 \
  "DEF:rangem=$2/dump1090_range-max_range.rrd:value:MAX" \
  "CDEF:range=rangem,0.001,*" \
  "LINE1:range#0000FF:max range" \
  --watermark "Drawn: $nowlit";
}

signal_graph() {
rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "$3 Signal Level" \
  --vertical-label "dBFS" \
  --upper-limit 2    \
  --lower-limit -15 \
  --rigid \
  --units-exponent 0 \
  "TEXTALIGN:center" \
  "DEF:signal=$2/dump1090_dbfs-signal.rrd:value:AVERAGE" \
  "DEF:peak=$2/dump1090_dbfs-peak_signal.rrd:value:AVERAGE" \
  "CDEF:us=signal,UN,-100,signal,IF" \
  "AREA:-100#00FF00:Mean Level\\:" \
  "AREA:us#FFFFFF" \
  "GPRINT:signal:AVERAGE:%4.1lf" \
  "LINE1:peak#0000FF:Peak Level\\:" \
  "GPRINT:peak:MAX:%4.1lf" \
  "LINE1:0#000000:Zero dBFS" \
  "LINE1:-3#FF0000:-3 dBFS" \
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
  aircraft_graph /var/www/html/collectd/dump1090-$2-aircraft-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  cpu_graph_dump1090 /var/www/html/collectd/dump1090-$2-cpu-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  tracks_graph /var/www/html/collectd/dump1090-$2-tracks-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5" 
}

system_graphs() {
  cpu_graph /var/www/html/collectd/system-$2-cpu-$4.png /var/lib/collectd/rrd/$1/aggregation-cpu-average "$3" "$4" "$5"
  df_root_graph /var/www/html/collectd/system-$2-df_root-$4.png /var/lib/collectd/rrd/$1/df-root "$3" "$4" "$5"
  disk_io_iops_graph /var/www/html/collectd/system-$2-disk_io_iops-$4.png /var/lib/collectd/rrd/$1/disk-mmcblk0 "$3" "$4" "$5"
  disk_io_octets_graph /var/www/html/collectd/system-$2-disk_io_octets-$4.png /var/lib/collectd/rrd/$1/disk-mmcblk0 "$3" "$4" "$5"
  memory_graph /var/www/html/collectd/system-$2-memory-$4.png /var/lib/collectd/rrd/$1/memory "$3" "$4" "$5"
  temp_graph_imperial /var/www/html/collectd/system-$2-temperature-$4.png /var/lib/collectd/rrd/$1/table-$2 "$3" "$4" "$5"
  #temp_graph_metric /var/www/html/collectd/system-$2-temperature-$4.png /var/lib/collectd/rrd/$1/table-$2 "$3" "$4" "$5"
  wlan0_graph /var/www/html/collectd/system-$2-wlan0_bandwidth-$4.png /var/lib/collectd/rrd/$1/interface-wlan0 "$3" "$4" "$5"
}

dump1090_receiver_graphs() {
  dump1090_graphs "$1" "$2" "$3" "$4" "$5"
  system_graphs "$1" "$2" "$3" "$4" "$5"
  local_rate_graph /var/www/html/collectd/dump1090-$2-local_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  local_trailing_rate_graph /var/www/html/collectd/dump1090-$2-local_trailing_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  range_graph_imperial /var/www/html/collectd/dump1090-$2-range-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  #range_graph_metric /var/www/html/collectd/dump1090-$2-range-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
  signal_graph /var/www/html/collectd/dump1090-$2-signal-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
}

dump1090_hub_graphs() {
  dump1090_graphs "$1" "$2" "$3" "$4" "$5"
  system_graphs "$1" "$2" "$3" "$4" "$5"
  remote_rate_graph /var/www/html/collectd/dump1090-$2-remote_rate-$4.png /var/lib/collectd/rrd/$1/dump1090-$2 "$3" "$4" "$5"
}

period="$1"
step="$2"
nowlit=`date '+%m/%d/%y %H:%M %Z'`;

dump1090_receiver_graphs localhost localhost "ADS-B" "$period" "$step"
#hub_graphs localhost rpi "ADS-B" "$period" "$step"
