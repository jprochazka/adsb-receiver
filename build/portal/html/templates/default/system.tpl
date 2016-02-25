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
{area:head}
            <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
            <script type="text/javascript">
                google.charts.load('current', {'packages':['gauge']});
                google.charts.setOnLoadCallback(drawChart);
                function drawChart() {

                    var data = google.visualization.arrayToDataTable([
                        ['Label', 'Value'],
                        ['Memory', 80],
                        ['CPU', 55],
                        ['Network', 68]
                    ]);

                    var options = {
                        width: 400, height: 120,
                        redFrom: 90, redTo: 100,
                        yellowFrom:75, yellowTo: 90,
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

                    setInterval(function() {
                        data.setValue(0, 1, 40 + Math.round(60 * Math.random()));
                        chart.draw(data, options);
                    }, 13000);
                    setInterval(function() {
                        data.setValue(1, 1, 40 + Math.round(60 * Math.random()));
                        chart.draw(data, options);
                    }, 5000);
                    setInterval(function() {
                        data.setValue(2, 1, 60 + Math.round(20 * Math.random()));
                        chart.draw(data, options);
                    }, 26000);
                    }
                </script>

{/area}
{area:contents}
            <div class="container">
                <h1>System information coming soon...</h1>
                <div id="chart_div" style="width: 400px; height: 120px;"></div>
            </div>
{/area}
{area:scripts/}