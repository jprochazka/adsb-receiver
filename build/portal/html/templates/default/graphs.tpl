{*

    ////////////////////////////////////////////////////////////////////////////////
    //                  ADS-B FEEDER PORTAL TEMPLATE INFORMATION                  //
    // ========================================================================== //
    // Template Set: default                                                      //
    // Template Name: graphs.tpl                                                  //
    // Version: 2.0.0                                                             //
    // Release Date:                                                              //
    // Author: Joe Prochazka                                                      //
    // Website: https://www.swiftbyte.com                                         //
    // Contributor: Marcus Gunther                                                //
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
                            {if page:networkInterface eq "eth0"}
                            <div class="col-md-6 text-center">
                                <a id ="system-eth0_bandwidth-link" href="#">
                                   <img id="system-eth0_bandwidth-image" class="img-responsive" src="#" alt="Bandwidth Usage (eth0)">
                                </a>
                            </div>
                            {else}
                            <div class="col-md-6 text-center">
                                <a id ="system-wlan0_bandwidth-link" href="#">
                                   <img id="system-wlan0_bandwidth-image" class="img-responsive" src="#" alt="Bandwidth Usage (wlan0)">
                                </a>
                            </div>
                            {/if}
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
{/area}
{area:scripts}
        <script src="/templates/{setting:template}/assets/js/graphs.js"></script>
{/area}