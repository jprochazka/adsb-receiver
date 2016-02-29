$(document).ready(function () {

    var form = $("#install-form");
    form.validate({
        errorPlacement: function errorPlacement(error, element) { element.before(error); },
        rules: {
            password1: {
                equalTo: "#password2"
            }
        }
    });

    form.children("div").steps({
        headerTag: "h2",
        bodyTag: "section",
        transitionEffect: "slideLeft",
        onStepChanging: function (event, currentIndex, newIndex) {
            form.validate().settings.ignore = ":disabled,:hidden";
            return form.valid();
        },
        onFinishing: function (event, currentIndex) {
            form.validate().settings.ignore = ":disabled";
            return form.valid();
        },
        onFinished: function (event, currentIndex) {
            alert("Submitted!");
        }
    });

    function changeDatabaseOptionsState() {
        var driver = $("#driver").val();

        $("#test-connection").hide();

        $("#host-div").hide();
        $("#username-div").hide();
        $("#password-div").hide();
        $("#database-div").hide();
        $("#prefix-div").hide();

        switch (driver) {
            case 'mysql':
            case 'pgsql':
            case 'sqlsrv':
                $("#host-div").show();
                $("#username-div").show();
                $("#password-div").show();
                $("#database-div").show();
                $("#prefix-div").show();
                $("#test-connection").show();
                break;
        }
    }

    changeDatabaseOptionsState();
    $("#driver").change(function () {
        changeDatabaseOptionsState();
    });
});