$(document).ready(function () {

    google.charts.load('current', { 'packages': ['gauge'] });
    google.charts.setOnLoadCallback(drawChart);

    function drawChart() {

        var data = google.visualization.arrayToDataTable([
            ['Label', 'Value'],
            ['Memory', 100],
            ['CPU', 100],
            ['In ' + ((bandwidthScale == 'kbps') ? '(KB/s)' : '(MB/s)'), 150],
            ['Out ' + ((bandwidthScale == 'kbps') ? '(KB/s)' : '(MB/s)'), 150],
            ['CPU Temp', 100]
        ]);

        var options = {
            width: 400, height: 120,
            redFrom: 90, redTo: 100,
            yellowFrom: 75, yellowTo: 90,
            minorTicks: 5
        };

        var chart = new google.visualization.Gauge(document.getElementById('chart_div'));

        chart.draw(data, options);

        data.setValue(0, 1, 0);
        data.setValue(1, 1, 0);
        data.setValue(2, 1, 0);
        data.setValue(3, 1, 0);
        data.setValue(4, 1, 0);
        chart.draw(data, options);

        setInterval(function () {
            $timestamp = new Date().getTime() / 1000;
            $.getJSON("/api/system.php?action=getMemoryInformation&time=" + $timestamp, function (json) {
                data.setValue(0, 1, Math.round(json.percent));
                chart.draw(data, options);
            });
        }, 3000);
        setInterval(function () {
            $timestamp = new Date().getTime() / 1000;
            $.getJSON("/api/system.php?action=getCpuInformation&time=" + $timestamp, function (json) {
                data.setValue(1, 1, Math.round(json.user));
                chart.draw(data, options);
            });
        }, 3000);
        setInterval(function () {
            $timestamp = new Date().getTime() / 1000;
            $.getJSON("/api/system.php?action=getNetworkInformation&time=" + $timestamp, function (json) {
                data.setValue(2, 1, Math.round(((bandwidthScale == 'kbps') ? json.rxKbps : json.rxMbps)));
                chart.draw(data, options);
            });
        }, 7000);
        setInterval(function () {
            $timestamp = new Date().getTime() / 1000;
            $.getJSON("/api/system.php?action=getNetworkInformation&time=" + $timestamp, function (json) {
                data.setValue(3, 1, Math.round(((bandwidthScale == 'kbps') ? json.txKbps : json.txMbps)));
                chart.draw(data, options);
            });
        }, 7000);
        setInterval(function () {
            $timestamp = new Date().getTime() / 1000;
            $.getJSON("/api/system.php?action=getCpuInformation&time=" + $timestamp, function (json) {
                data.setValue(4, 1, Math.round(json.temperature));
                chart.draw(data, options);
            });
        }, 3000);
    }

    // Convert uptime to a more readable format and increment it every second.
    var sec = Math.floor($("#uptime").text());
    function pad(val) {
        return val > 9 ? val : "0" + val;
    }
    setInterval( function(){
        ++sec;
        var seconds = sec;

        var days = pad(parseInt(sec / 86400, 10));
        seconds = seconds - (days * 86400);

        var hours = pad(parseInt(seconds / 3600, 10));
        seconds = seconds - (hours * 3600);

        var minutes = pad(parseInt(seconds / 60, 10));
        seconds = pad(seconds - (minutes * 60));

        $("#uptime").text(days + ':' + hours + ':' + minutes + ':' + seconds);
    }, 1000);
});
