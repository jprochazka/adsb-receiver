        <div id="wrapper">
            <nav class="navbar navbar-default navbar-fixed-top" role="navigation">
                <div class="container">
                    <div class="navbar-header">
                        <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
                            <span class="sr-only">Toggle navigation</span>
                            <span class="icon-bar"></span>
                            <span class="icon-bar"></span>
                            <span class="icon-bar"></span>
                        </button>
                        <a class="navbar-brand" href="/">ADS-B Feeder</a>
                    </div>
                    <div class="navbar-collapse collapse">
                        <ul class="nav navbar-nav">
                            <li id="graphs-link"><a href="/graphs/">Performance Graphs</a></li>
                            <li id="map-link" class="active"><a href="/map/">Live Dump1090 Map</a></li>
                            <!-- Plane Finder ADS-B Client Link Placeholder -->
                        </ul>
                    </div>
                </div>
            </nav>
            <div id="iframe-wrapper">
                <iframe id="map" src="/dump1090/gmap.html"></iframe>
            </div>
            <div id="push"></div>
        </div>