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

    // Display images for the requested time frame and create links to full sized images for the requested time frame.
    var element;
    $("#dump1090-local_trailing_rate-image").attr("src", "graphs/dump1090-" + $hostName + "-local_trailing_rate-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#dump1090-local_trailing_rate-link").attr("href", "graphs/dump1090-" + $hostName + "-local_trailing_rate-" + $timeFrame + ".svg?time=" + $timestamp);

    $("#dump1090-local_rate-image").attr("src", "graphs/dump1090-" + $hostName + "-local_rate-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#dump1090-local_rate-link").attr("href", "graphs/dump1090-" + $hostName + "-local_rate-" + $timeFrame + ".svg?time=" + $timestamp);

    $("#dump1090-aircraft_message_rate-image").attr("src", "graphs/dump1090-" + $hostName + "-aircraft_message_rate-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#dump1090-aircraft_message_rate-link").attr("href", "graphs/dump1090-" + $hostName + "-aircraft_message_rate-" + $timeFrame + ".svg?time=" + $timestamp);

    $("#dump1090-aircraft-image").attr("src", "graphs/dump1090-" + $hostName + "-aircraft-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#dump1090-aircraft-link").attr("href", "graphs/dump1090-" + $hostName + "-aircraft-" + $timeFrame + ".svg?time=" + $timestamp);

    $("#dump1090-tracks-image").attr("src", "graphs/dump1090-" + $hostName + "-tracks-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#dump1090-tracks-link").attr("href", "graphs/dump1090-" + $hostName + "-tracks-" + $timeFrame + ".svg?time=" + $timestamp);

    element =  document.getElementById('dump1090-range_imperial_nautical-image');
    if (typeof(element) != 'undefined' && element != null) {
        $("#dump1090-range_imperial_nautical-image").attr("src", "graphs/dump1090-" + $hostName + "-range_imperial_nautical-" + $timeFrame + ".svg?time=" + $timestamp);
        $("#dump1090-range_imperial_nautical-link").attr("href", "graphs/dump1090-" + $hostName + "-range_imperial_nautical-" + $timeFrame + ".svg?time=" + $timestamp);
    }

    element =  document.getElementById('dump1090-range_imperial_statute-image');
    if (typeof(element) != 'undefined' && element != null) {
        $("#dump1090-range_imperial_statute-image").attr("src", "graphs/dump1090-" + $hostName + "-range_imperial_statute-" + $timeFrame + ".svg?time=" + $timestamp);
        $("#dump1090-range_imperial_statute-link").attr("href", "graphs/dump1090-" + $hostName + "-range_imperial_statute-" + $timeFrame + ".svg?time=" + $timestamp);
    }

    element =  document.getElementById('dump1090-range_metric-image');
    if (typeof(element) != 'undefined' && element != null) {
        $("#dump1090-range_metric-image").attr("src", "graphs/dump1090-" + $hostName + "-range_metric-" + $timeFrame + ".svg?time=" + $timestamp);
        $("#dump1090-range_metric-link").attr("href", "graphs/dump1090-" + $hostName + "-range_metric-" + $timeFrame + ".svg?time=" + $timestamp);
    }

    $("#dump1090-signal-image").attr("src", "graphs/dump1090-" + $hostName + "-signal-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#dump1090-signal-link").attr("href", "graphs/dump1090-" + $hostName + "-signal-" + $timeFrame + ".svg?time=" + $timestamp);

    $("#dump1090-cpu-image").attr("src", "graphs/dump1090-" + $hostName + "-cpu-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#dump1090-cpu-link").attr("href", "graphs/dump1090-" + $hostName + "-cpu-" + $timeFrame + ".svg?time=" + $timestamp);

    $("#system-cpu-image").attr("src", "graphs/system-" + $hostName + "-cpu-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#system-cpu-link").attr("href", "graphs/system-" + $hostName + "-cpu-" + $timeFrame + ".svg?time=" + $timestamp);

    element =  document.getElementById('system-eth0_bandwidth-image');
    if (typeof(element) != 'undefined' && element != null) {
        $("#system-eth0_bandwidth-image").attr("src", "graphs/system-" + $hostName + "-eth0_bandwidth-" + $timeFrame + ".svg?time=" + $timestamp);
        $("#system-eth0_bandwidth-link").attr("href", "graphs/system-" + $hostName + "-eth0_bandwidth-" + $timeFrame + ".svg?time=" + $timestamp);
    }
    element =  document.getElementById('system-wlan0_bandwidth-image');
    if (typeof(element) != 'undefined' && element != null) {
        $("#system-wlan0_bandwidth-image").attr("src", "graphs/system-" + $hostName + "-wlan0_bandwidth-" + $timeFrame + ".svg?time=" + $timestamp);
        $("#system-wlan0_bandwidth-link").attr("href", "graphs/system-" + $hostName + "-wlan0_bandwidth-" + $timeFrame + ".svg?time=" + $timestamp);
    }
    
    $("#system-memory-image").attr("src", "graphs/system-" + $hostName + "-memory-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#system-memory-link").attr("href", "graphs/system-" + $hostName + "-memory-" + $timeFrame + ".svg?time=" + $timestamp);

    element =  document.getElementById('system-temperature_imperial-image');
    if (typeof(element) != 'undefined' && element != null) {
        $("#system-temperature_imperial-image").attr("src", "graphs/system-" + $hostName + "-temperature_imperial-" + $timeFrame + ".svg?time=" + $timestamp);
        $("#system-temperature_imperial-link").attr("href", "graphs/system-" + $hostName + "-temperature_imperial-" + $timeFrame + ".svg?time=" + $timestamp);
    }
    element =  document.getElementById('system-temperature_metric-image');
    if (typeof(element) != 'undefined' && element != null) {
        $("#system-temperature_metric-image").attr("src", "graphs/system-" + $hostName + "-temperature_metric-" + $timeFrame + ".svg?time=" + $timestamp);
        $("#system-temperature_metric-link").attr("href", "graphs/system-" + $hostName + "-temperature_metric-" + $timeFrame + ".svg?time=" + $timestamp);
    }

    $("#system-df_root-image").attr("src", "graphs/system-" + $hostName + "-df_root-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#system-df_root-link").attr("href", "graphs/system-" + $hostName + "-df_root-" + $timeFrame + ".svg?time=" + $timestamp);

    $("#system-disk_io_iops-image").attr("src", "graphs/system-" + $hostName + "-disk_io_iops-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#system-disk_io_iops-link").attr("href", "graphs/system-" + $hostName + "-disk_io_iops-" + $timeFrame + ".svg?time=" + $timestamp);

    $("#system-disk_io_octets-image").attr("src", "graphs/system-" + $hostName + "-disk_io_octets-" + $timeFrame + ".svg?time=" + $timestamp);
    $("#system-disk_io_octets-link").attr("href", "graphs/system-" + $hostName + "-disk_io_octets-" + $timeFrame + ".svg?time=" + $timestamp);

	// Set the button related to the selected time frame to active.
    $("#btn-1h").removeClass('active');
    $("#btn-6h").removeClass('active');
    $("#btn-24h").removeClass('active');
    $("#btn-7d").removeClass('active');
    $("#btn-30d").removeClass('active');
    $("#btn-365d").removeClass('active');
    $("#btn-" + $timeFrame).addClass('active');
}