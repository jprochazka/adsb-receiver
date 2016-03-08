$(document).ready(function () {
    $("#password1").prop('disabled', true);
    $("#password2").prop('disabled', true);

    // Enable/disable password fields if content is contained in the current password textbox.
    $("#password").keyup(function () {
        if ($("#password").val().length > 0) {
            $("#password1").prop('disabled', false);
            $("#password2").prop('disabled', false);
        } else {
            $("#password1").val("");
            $("#password2").val("");
            $("#password1").prop('disabled', true);
            $("#password2").prop('disabled', true);
        }
    });

    // Form validation.
    var form = $("#install-form");
    form.validate().settings.ignore = ":disabled";
    form.validate({
        errorPlacement: function errorPlacement(error, element) { element.before(error); },
        rules: {
            password1: {
                minlength: 6,
                equalTo: "#password2"
            }
        }
    });
});