#!/bin/bash

# Assign the Lighthttpd document root directory to a variable.
RAWDOCUMENTROOT=`/usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -p | grep server.document-root`
DOCUMENTROOT=`sed 's/.*"\(.*\)"[^"]*$/\1/' <<< $RAWDOCUMENTROOT`

renice -n 5 -p $$

## SYSTEM GRAPHS

cpu_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 1010 \
  --height 200 \
  --step "$5" \
  --title "Overall CPU Utilization" \
  --vertical-label "CPU %" \
  --lower-limit 0 \
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
  "AREA:psteal#0000FF:steal:STACK" \
  "AREA:pwait#C00000:io:STACK" \
  "AREA:psystem#FF0000:sys:STACK" \
  "AREA:puser#40FF40:user:STACK" \
  "AREA:pnice#008000:nice\c:STACK" \
  --watermark "Drawn: $nowlit";
}

df_root_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 496 \
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
  "AREA:totalused#4169E1:Used:STACK" \
  "AREA:free#32C734:Free\c:STACK" \
  "COMMENT: \n" \
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
  --vertical-label "Bytes/Sec" \
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
  --watermark "Drawn: $nowlit";
}

eth0_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 480 \
  --height 200 \
  --step "$5" \
  --title "Bandwidth Usage (eth0)" \
  --vertical-label "Bytes/Sec" \
  "TEXTALIGN:center" \
  "DEF:rx=$2/if_octets.rrd:rx:AVERAGE" \
  "DEF:tx=$2/if_octets.rrd:tx:AVERAGE" \
  "CDEF:tx_neg=tx,-1,*" \
  "AREA:rx#32CD32:Incoming" \
  "LINE1:rx#336600" \
  "GPRINT:rx:MAX:Max\:%8.1lf %s" \
  "GPRINT:rx:AVERAGE:Avg\:%8.1lf %S" \
  "GPRINT:rx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
  "AREA:tx_neg#4169E1:Outgoing" \
  "LINE1:tx_neg#0033CC" \
  "GPRINT:tx:MAX:Max\:%8.1lf %S" \
  "GPRINT:tx:AVERAGE:Avg\:%8.1lf %S" \
  "GPRINT:tx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
  --watermark "Drawn: $nowlit";
}

memory_graph() {
  rrdtool graph \
  "$1" \
  --start end-$4 \
  --width 496 \
  --height 200 \
  --step "$5" \
  --lower-limit 0 \
  --title "Memory Utilization" \
  --vertical-label "" \
  "TEXTALIGN:center" \
  "DEF:buffered=$2/memory-buffered.rrd:value:AVERAGE" \
  "DEF:cached=$2/memory-cached.rrd:value:AVERAGE" \
  "DEF:free=$2/memory-free.rrd:value:AVERAGE" \
  "DEF:used=$2/memory-used.rrd:value:AVERAGE" \
  "AREA:used#4169E1:Used:STACK" \
  "AREA:buffered#32C734:Buffered:STACK" \
  "AREA:cached#00FF00:Cached:STACK" \
  "AREA:free#FFFFFF:Free\c:STACK" \
  "COMMENT: \n" \
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
  "DEF:traw=$2/temperature.rrd:value:MAX" \
  "CDEF:tta=traw,1000,/" \
  "CDEF:ttb=tta,1.8,*" \
  "CDEF:ttc=ttb,32,+" \
  "AREA:ttc#ffcc00" \
  "COMMENT: \n" \
  "COMMENT: \n" \
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
  "DEF:traw=$2/temperature.rrd:value:MAX" \
  "CDEF:tfin=traw,1000,/" \
  "AREA:tfin#ffcc00" \
  "COMMENT: \n" \
  "COMMENT: \n" \
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
  --vertical-label "Bytes/Sec" \
  "TEXTALIGN:center" \
  "DEF:rx=$2/if_octets.rrd:rx:AVERAGE" \
  "DEF:tx=$2/if_octets.rrd:tx:AVERAGE" \
  "CDEF:tx_neg=tx,-1,*" \
  "AREA:rx#32CD32:Incoming" \
  "LINE1:rx#336600" \
  "GPRINT:rx:MAX:Max\:%8.1lf %s" \
  "GPRINT:rx:AVERAGE:Avg\:%8.1lf %S" \
  "GPRINT:rx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
  "AREA:tx_neg#4169E1:Outgoing" \
  "LINE1:tx_neg#0033CC" \
  "GPRINT:tx:MAX:Max\:%8.1lf %S" \
  "GPRINT:tx:AVERAGE:Avg\:%8.1lf %S" \
  "GPRINT:tx:LAST:Current\:%8.1lf %Sbytes/sec\c" \
  --watermark "Drawn: $nowlit";
}

system_graphs() {
  cpu_graph ${DOCUMENTROOT}/graphs/system-$2-cpu-$4.png /var/lib/collectd/rrd/$1/aggregation-cpu-average "$3" "$4" "$5"
  df_root_graph ${DOCUMENTROOT}/graphs/system-$2-df_root-$4.png /var/lib/collectd/rrd/$1/df-root "$3" "$4" "$5"
  disk_io_iops_graph ${DOCUMENTROOT}/graphs/system-$2-disk_io_iops-$4.png /var/lib/collectd/rrd/$1/disk-mmcblk0 "$3" "$4" "$5"
  disk_io_octets_graph ${DOCUMENTROOT}/graphs/system-$2-disk_io_octets-$4.png /var/lib/collectd/rrd/$1/disk-mmcblk0 "$3" "$4" "$5"
  eth0_graph ${DOCUMENTROOT}/graphs/system-$2-eth0_bandwidth-$4.png /var/lib/collectd/rrd/$1/interface-eth0 "$3" "$4" "$5"
  memory_graph ${DOCUMENTROOT}/graphs/system-$2-memory-$4.png /var/lib/collectd/rrd/$1/memory "$3" "$4" "$5"
  temp_graph_imperial ${DOCUMENTROOT}/graphs/system-$2-temperature_imperial-$4.png /var/lib/collectd/rrd/$1/thermal-thermal_zone0 "$3" "$4" "$5"
  temp_graph_metric ${DOCUMENTROOT}/graphs/system-$2-temperature_metric-$4.png /var/lib/collectd/rrd/$1/thermal-thermal_zone0 "$3" "$4" "$5"
  wlan0_graph ${DOCUMENTROOT}/graphs/system-$2-wlan0_bandwidth-$4.png /var/lib/collectd/rrd/$1/interface-wlan0 "$3" "$4" "$5"
}

period="$1"
step="$2"
nowlit=`date '+%m/%d/%y %H:%M %Z'`;

system_graphs localhost localhost "System" "$period" "$step"
