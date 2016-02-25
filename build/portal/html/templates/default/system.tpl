{*

    ////////////////////////////////////////////////////////////////////////////////
    //                 ADS-B RECEIVER PORTAL TEMPLATE INFORMATION                 //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: system.tpl                                                  //
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
{area:head/}
{area:contents}
            <div class="container">
                <h1>System information coming soon...</h1>
                <div id="chart_div" style="width: 400px; height: 120px;"></div>
            </div>
{/area}
{area:scripts}
            <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
            <script type="text/javascript">
                $(document).ready(function () {

                    google.charts.load('current', { 'packages': ['gauge'] });
                    google.charts.setOnLoadCallback(drawChart);

                    function drawChart() {

                        var data = google.visualization.arrayToDataTable([
                            ['Label', 'Value'],
                            ['Memory', 100],
                            ['CPU', 100],
                            ['Network In', 100]
                            ['Network Out', 100]
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
                        chart.draw(data, options);
                        data.setValue(1, 1, 0);
                        chart.draw(data, options);
                        data.setValue(2, 1, 0);
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
                                data.setValue(2, 1, Math.round(json.rx));
                                chart.draw(data, options);
                            });
                        }, 3000);

                    }
                });
            </script>
{/area}