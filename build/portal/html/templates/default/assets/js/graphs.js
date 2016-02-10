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
<?php   if ($measurementRange == "imperial") { ?>
    $("#dump1090-range-image").attr("src", "graphs/dump1090-" + $hostName + "-range-imperial-" + $timeFrame + ".png?time=" + $timestamp);
<?php   } else { ?>
    $("#dump1090-range-image").attr("src", "graphs/dump1090-" + $hostName + "-range-metric-" + $timeFrame + ".png?time=" + $timestamp);
<?php   } ?>
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
<?php   if ($measurementRange == "imperial") { ?>
    $("#dump1090-range-link").attr("href", "graphs/dump1090-" + $hostName + "-range-imperial-" + $timeFrame + ".png");
<?php   } else { ?>
    $("#dump1090-range-link").attr("href", "graphs/dump1090-" + $hostName + "-range-metric-" + $timeFrame + ".png");
<?php   } ?>
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