<?php

    ////////////////////////////////////////////////////////////////////////////////
    //                  ADS-B FEEDER PORTAL TEMPLATE INFORMATION                  //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: graphs                                                      //
    // Version: 1.0.3                                                             //
    // Release Date: 11-02-2016                                                   //
    // Author: Joe Prochazka                                                      //
    // Website: https://www.swiftbyte.com                                         //
    // Contributor: Marcus Gunther                                                //
    // ========================================================================== //
    // Copyright and Licensing Information:                                       //
    //                                                                            //
    // Copyright (c) 2016 Joseph A. Prochazka                                     //
    //                                                                            //
    // This template set is licensed under The MIT License (MIT)                  //
    // A copy of the license can be found package along with these files.         //
    ////////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////
    // Additional <head> content.
    function headContent() {}

    ///////////////////
    // Page content.
    function pageContent() {
        global $networkInterface;
?>
            <div class="container">
                <h1>Performance Graphs</h1>
                <div class="btn-group" role="group">
                    <button type="button" id="btn-1h" class="btn btn-default btn-sm active" onclick="switchView('1h')">Hourly</button>
                    <button type="button" id="btn-6h" class="btn btn-default btn-sm" onclick="switchView('6h')">Six Hours</button>
                    <button type="button" id="btn-24h" class="btn btn-default btn-sm" onclick="switchView('24h')">Daily</button>
                    <button type="button" id="btn-7d" class="btn btn-default btn-sm" onclick="switchView('7d')">Weekly</button>
                    <button type="button" id="btn-30d" class="btn btn-default btn-sm" onclick="switchView('30d')">Monthly</button>
                    <button type="button" id="btn-365d" class="btn btn-default btn-sm" onclick="switchView('365d')">Yearly</button>
                </div>
                <div class="padding"></div>
                <!-- Dump1090 Graphs -->
                <div class="panel panel-default">
                    <div class="panel-heading">Dump1090 Graphs</div>
                    <div class="panel-body">
                        <div class="row">
                            <div class="col-md-12 text-center">
                                <a id ="dump1090-local_trailing_rate-link" href="#">
                                    <img id="dump1090-local_trailing_rate-image" class="img-responsive" src="#" alt="Message Rate (Trailing)">
                                </a>
                            </div>
                        </div>
                        <div class="padding"></div>
                        <div class="row">
                            <div class="col-md-6 text-center">
                                <a id ="dump1090-aircraft-link" href="#">
                                   <img id="dump1090-aircraft-image" class="img-responsive" src="#" alt="Aircraft Seen">
                                </a>
                            </div>
                            <div class="col-md-6 text-center">
                                <a id ="dump1090-tracks-link" href="#">
                                   <img id="dump1090-tracks-image" class="img-responsive" src="#" alt="Tracks Seen">
                                </a>
                            </div>
                        </div>
                        <div class="padding"></div>
                        <div class="row">
                            <div class="col-md-6 text-center">
                                <a id ="dump1090-range-link" href="#">
                                    <img id="dump1090-range-image" class="img-responsive" src="#" alt="Max Range">
                                </a>
                            </div>
                            <div class="col-md-6 text-center">
                                <a id ="dump1090-signal-link" href="#">
                                    <img id="dump1090-signal-image" class="img-responsive" src="#" alt="Signal Level">
                                </a>
                            </div>
                        </div>
                        <div class="padding"></div>
                        <div class="row">
                            <div class="col-md-6 text-center">
                                <a id ="dump1090-local_rate-link" href="#">
                                   <img id="dump1090-local_rate-image" class="img-responsive" src="#" alt="Message Rate">
                                </a>
                            </div>
                            <div class="col-md-6 text-center">
                                <a id ="dump1090-aircraft_message_rate-link" href="#">
                                    <img id="dump1090-aircraft_message_rate-image" class="img-responsive" src="#" alt="Aircraft Message Rate">
                                </a>
                            </div>
                        </div>
                        <div class="padding"></div>
                        <div class="row">
                            <div class="col-md-6 text-center">
                                <a id ="dump1090-cpu-link" href="#">
                                    <img id="dump1090-cpu-image" class="img-responsive" src="#" alt="CPU Utilization">
                                </a>
                            </div>
                            <div class="col-md-6 text-center"></div>
                        </div>
                    </div>
                </div>
                <!-- System Graphs -->
                <div class="panel panel-default">
                    <div class="panel-heading">System Graphs</div>
                    <div class="panel-body">
                        <div class="row">
                            <div class="col-md-12 text-center">
                                <a id ="system-cpu-link" href="#">
                                    <img id="system-cpu-image" class="img-responsive" src="#" alt="Overall CPU Utilization">
                                </a>
                            </div>
                        </div>
                        <div class="padding"></div>
                        <div class="row">
                            <div class="col-md-6 text-center">
                                <a id ="system-temperature-link" href="#">
                                   <img id="system-temperature-image" class="img-responsive" src="#" alt="Core Temperature">
                                </a>
                            </div>
                            <div class="col-md-6 text-center">
                                <a id ="system-memory-link" href="#">
                                   <img id="system-memory-image" class="img-responsive" src="#" alt="Memory Utilization">
                                </a>
                            </div>
                        </div>
                        <div class="padding"></div>
                        <div class="row">
<?php   if ($networkInterface == "eth0") { ?>
                            <div class="col-md-6 text-center">
                                <a id ="system-eth0_bandwidth-link" href="#">
                                   <img id="system-eth0_bandwidth-image" class="img-responsive" src="#" alt="Bandwidth Usage (eth0)">
                                </a>
                            </div>
<?php   } else { ?>
                            <div class="col-md-6 text-center">
                                <a id ="system-wlan0_bandwidth-link" href="#">
                                   <img id="system-wlan0_bandwidth-image" class="img-responsive" src="#" alt="Bandwidth Usage (wlan0)">
                                </a>
                            </div>
<?php   } ?>
                            <div class="col-md-6 text-center">
                                <a id ="system-df_root-link" href="#">
                                    <img id="system-df_root-image" class="img-responsive" src="#" alt="Disk Space Usage (/)">
                                </a>
                            </div>
                        </div>
                        <div class="padding"></div>
                        <div class="row">
                            <div class="col-md-6 text-center">
                                <a id ="system-disk_io_iops-link" href="#">
                                    <img id="system-disk_io_iops-image" class="img-responsive" src="#" alt="Disk I/O - IOPS">
                                </a>
                            </div>
                            <div class="col-md-6 text-center">
                                <a id ="system-disk_io_octets-link" href="#">
                                    <img id="system-disk_io_octets-image" class="img-responsive" src="#" alt="Disk I/O - Bandwidth">
                                </a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
<?php
    }

    /////////////////////////////////////////////////
    // Content to be added to the scripts section.
    function scriptContent() {
        global $measurementRange, $measurementTemperature, $networkInterface;
?>
        <script type="text/javascript">
            //*** BEGIN USER DEFINED VARIABLES ***//

            // Set the default time frame to use when loading images when the page is first accessed.
            // Can be set to 1h, 6h, 24h, 7d, 30d, or 365d.
            $timeFrame = '24h';

            // Set this to the hostname of the system which is running dump1090.
            $hostName = 'localhost';

            // Set the page refresh interval in milliseconds.
            $refreshInterval = 60000

            //*** END USER DEFINED VARIABLES ***//


            //*** DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING ***//

            $(document).ready(function () {
                // Display the images for the supplied time frame.
                switchView($timeFrame);

                // Refresh images contained within the page every X milliseconds.
                window.setInterval(function() {
                    switchView($timeFrame)
                }, $refreshInterval);
            });

            function switchView(newTimeFrame) {
                // Set the the $timeFrame variable to the one selected.
                $timeFrame = newTimeFrame;

                // Set the timestamp variable to be used in querystring.
                $timestamp = new Date().getTime() / 1000

                // Display images for the requested time frame.
                $("#dump1090-local_trailing_rate-image").attr("src", "graphs/dump1090-" + $hostName + "-local_trailing_rate-" + $timeFrame + ".png?time=" + $timestamp);
                $("#dump1090-local_rate-image").attr("src", "graphs/dump1090-" + $hostName + "-local_rate-" + $timeFrame + ".png?time=" + $timestamp);
                $("#dump1090-aircraft_message_rate-image").attr("src", "graphs/dump1090-" + $hostName + "-aircraft_message_rate-" + $timeFrame + ".png?time=" + $timestamp);
                $("#dump1090-aircraft-image").attr("src", "graphs/dump1090-" + $hostName + "-aircraft-" + $timeFrame + ".png?time=" + $timestamp);
                $("#dump1090-tracks-image").attr("src", "graphs/dump1090-" + $hostName + "-tracks-" + $timeFrame + ".png?time=" + $timestamp);
<?php   if ($measurementRange == "imperial_nm") { ?>
                $("#dump1090-range-image").attr("src", "graphs/dump1090-" + $hostName + "-range-imperial-nm-" + $timeFrame + ".png?time=" + $timestamp);<?php   } ?>
<?php   if ($measurementRange == "imperial_sm") { ?>
                $("#dump1090-range-image").attr("src", "graphs/dump1090-" + $hostName + "-range-imperial-sm-" + $timeFrame + ".png?time=" + $timestamp);<?php   } ?>
<?php   if ($measurementRange == "metric") { ?>
                $("#dump1090-range-image").attr("src", "graphs/dump1090-" + $hostName + "-range-metric-" + $timeFrame + ".png?time=" + $timestamp);<?php   } ?>
                $("#dump1090-signal-image").attr("src", "graphs/dump1090-" + $hostName + "-signal-" + $timeFrame + ".png?time=" + $timestamp);
                $("#dump1090-cpu-image").attr("src", "graphs/dump1090-" + $hostName + "-cpu-" + $timeFrame + ".png?time=" + $timestamp);
                $("#system-cpu-image").attr("src", "graphs/system-" + $hostName + "-cpu-" + $timeFrame + ".png?time=" + $timestamp);
<?php   if ($networkInterface == "eth0") { ?>
                $("#system-eth0_bandwidth-image").attr("src", "graphs/system-" + $hostName + "-eth0_bandwidth-" + $timeFrame + ".png?time=" + $timestamp);
<?php   } else { ?>
                $("#system-wlan0_bandwidth-image").attr("src", "graphs/system-" + $hostName + "-wlan0_bandwidth-" + $timeFrame + ".png?time=" + $timestamp);
<?php   } ?>
                $("#system-memory-image").attr("src", "graphs/system-" + $hostName + "-memory-" + $timeFrame + ".png?time=" + $timestamp);
<?php   if ($measurementTemperature == "imperial") { ?>
                $("#system-temperature-image").attr("src", "graphs/system-" + $hostName + "-temperature-imperial-" + $timeFrame + ".png?time=" + $timestamp);
<?php   } else { ?>
                $("#system-temperature-image").attr("src", "graphs/system-" + $hostName + "-temperature-metric-" + $timeFrame + ".png?time=" + $timestamp);
<?php   } ?>
                $("#system-df_root-image").attr("src", "graphs/system-" + $hostName + "-df_root-" + $timeFrame + ".png?time=" + $timestamp);
                $("#system-disk_io_iops-image").attr("src", "graphs/system-" + $hostName + "-disk_io_iops-" + $timeFrame + ".png?time=" + $timestamp);
                $("#system-disk_io_octets-image").attr("src", "graphs/system-" + $hostName + "-disk_io_octets-" + $timeFrame + ".png?time=" + $timestamp);

                // Create links to full sized images for the requested time frame.
                $("#dump1090-local_trailing_rate-link").attr("href", "graphs/dump1090-" + $hostName + "-local_trailing_rate-" + $timeFrame + ".png");
                $("#dump1090-local_rate-link").attr("href", "graphs/dump1090-" + $hostName + "-local_rate-" + $timeFrame + ".png");
                $("#dump1090-aircraft_message_rate-link").attr("href", "graphs/dump1090-" + $hostName + "-aircraft_message_rate-" + $timeFrame + ".png");
                $("#dump1090-aircraft-link").attr("href", "graphs/dump1090-" + $hostName + "-aircraft-" + $timeFrame + ".png");
                $("#dump1090-tracks-link").attr("href", "graphs/dump1090-" + $hostName + "-tracks-" + $timeFrame + ".png");
<?php   if ($measurementRange == "imperial_nm") { ?>
                $("#dump1090-range-link").attr("href", "graphs/dump1090-" + $hostName + "-range-imperial-nm-" + $timeFrame + ".png"); <?php   } ?>
<?php   if ($measurementRange == "imperial_sm") { ?>
                $("#dump1090-range-link").attr("href", "graphs/dump1090-" + $hostName + "-range-imperial-sm-" + $timeFrame + ".png"); <?php   } ?>
<?php   if ($measurementRange == "metric") { ?>
                $("#dump1090-range-link").attr("href", "graphs/dump1090-" + $hostName + "-range-metric-" + $timeFrame + ".png"); <?php   } ?>
                $("#dump1090-signal-link").attr("href", "graphs/dump1090-" + $hostName + "-signal-" + $timeFrame + ".png");
                $("#dump1090-cpu-link").attr("href", "graphs/dump1090-" + $hostName + "-cpu-" + $timeFrame + ".png");
                $("#system-cpu-link").attr("href", "graphs/system-" + $hostName + "-cpu-" + $timeFrame + ".png");
<?php   if ($networkInterface == "eth0") { ?>
                $("#system-eth0_bandwidth-link").attr("href", "graphs/system-" + $hostName + "-eth0_bandwidth-" + $timeFrame + ".png");
<?php   } else { ?>
                $("#system-wlan0_bandwidth-link").attr("href", "graphs/system-" + $hostName + "-wlan0_bandwidth-" + $timeFrame + ".png");
<?php   } ?>
                $("#system-memory-link").attr("href", "graphs/system-" + $hostName + "-memory-" + $timeFrame + ".png");
<?php   if ($measurementTemperature == "imperial") { ?>
                $("#system-temperature-link").attr("href", "graphs/system-" + $hostName + "-temperature-imperial-" + $timeFrame + ".png");
<?php   } else { ?>
                $("#system-temperature-link").attr("href", "graphs/system-" + $hostName + "-temperature-metric-" + $timeFrame + ".png");
<?php   } ?>
                $("#system-df_root-link").attr("href", "graphs/system-" + $hostName + "-df_root-" + $timeFrame + ".png");
                $("#system-disk_io_iops-link").attr("href", "graphs/system-" + $hostName + "-disk_io_iops-" + $timeFrame + ".png");
                $("#system-disk_io_octets-link").attr("href", "graphs/system-" + $hostName + "-disk_io_octets-" + $timeFrame + ".png");

	            // Set the button related to the selected time frame to active.
                $("#btn-1h").removeClass('active');
                $("#btn-6h").removeClass('active');
                $("#btn-24h").removeClass('active');
                $("#btn-7d").removeClass('active');
                $("#btn-30d").removeClass('active');
                $("#btn-365d").removeClass('active');
                $("#btn-" + $timeFrame).addClass('active');
            }
        </script>
<?php
    }
?>
