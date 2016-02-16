function checkFlights() {
    $.getJSON("/api/notifications.php?type=flights&time=" + new Date().getTime(), function (data) {
        var flightCount = 0;
        $("#flight-notifications ul").empty();
        $.each(data, function (key, val) {
            $("#flight-notifications ul").append("<li id='" + key + "'>" + val + "</li>");
            flightCount++
        });

        if (flightCount > 0) {
            $("#flight-notifications").show();
        } else {
            $("#flight-notifications").hide();
        }
    });
}

$(document).ready(function () {
    checkFlights();
    var refreshId = setInterval("checkFlights()", 5000);
});