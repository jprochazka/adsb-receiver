function checkFlights() {
    pathArray = location.href.split( '/' );
    protocol = pathArray[0];
    host = pathArray[2];

    $.getJSON(protocol + '//' + host + "/api/notifications.php?type=flights&time=" + new Date().getTime(), function (data) {
        if (getCookie("flights") != data) {
            var flightCount = 0;
            $("#flight-notifications ul").empty();
            $.each(data, function (key, val) {
                if (val != '') {
                    $("#flight-notifications ul").append("<li id='" + key + "'>" + val + "</li>");
                    flightCount++;
               }
            });

            if (flightCount > 0) {
                $("#flight-notifications").modal('show');
            } else {
                $("#flight-notifications").modal('hide');
            }

            document.cookie = "flights=" + data;
        }
    });
}

$(document).ready(function () {
    checkFlights();
    var refreshId = setInterval("checkFlights()", 5000);
});

function getCookie(cname) {
     var name = cname + "=";
     var ca = document.cookie.split(';');
     for(var i=0; i<ca.length; i++) {
         var c = ca[i];
         while (c.charAt(0)==' ') c = c.substring(1);
         if (c.indexOf(name) == 0) return c.substring(name.length,c.length);
     }
     return "";
 }