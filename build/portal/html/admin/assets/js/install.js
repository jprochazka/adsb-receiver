$(document).ready(function () {

    var form = $("#install-form");

    form.children("div").steps({
        headerTag: "h2",
        bodyTag: "section",
        transitionEffect: "slideLeft",
        //stepsOrientation: "vertical",
        onStepChanging: function (event, currentIndex, newIndex) {

            if (newIndex === 1 && Number($("#permissions").val()) != 1) {
                return false;
            }

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

    form.validate({
        errorPlacement: function errorPlacement(error, element) { element.before(error); },
        rules: {
            password1: {
                minlength: 6,
                equalTo: "#password2"
            }
        }
    });

    function changeDatabaseOptionsState() {
        var driver = $("#driver").val();

        $("#test-connection").hide();
        $("#required-p").hide();

        $("#host-div").hide();
        $("#username-div").hide();
        $("#password-div").hide();
        $("#database-div").hide();
        $("#prefix-div").hide();

        $("#host").prop('disabled', true);
        $("#username").prop('disabled', true);
        $("#password").prop('disabled', true);
        $("#database").prop('disabled', true);
        $("#prefix").prop('disabled', true);

        switch (driver) {
            case 'mysql':
            case 'pgsql':
            case 'sqlsrv':
                $("#test-connection").show();
                $("#required-p").show();

                $("#host").prop('disabled', false);
                $("#username").prop('disabled', false);
                $("#password").prop('disabled', false);
                $("#database").prop('disabled', false);
                $("#prefix").prop('disabled', false);

                $("#host-div").show();
                $("#username-div").show();
                $("#password-div").show();
                $("#database-div").show();
                $("#prefix-div").show();

                break;
        }
    }

    changeDatabaseOptionsState();
    $("#driver").change(function () {
        changeDatabaseOptionsState();
    });

    // Password Strength Checker

    $('#password1').keyup(function () {
        $('#result').html(checkStrength($('#password1').val()))
    });

    function checkStrength(password) {
		// The initial strength of the password.
		var strength = 0
		
		// If the length of thepassword is less than 6...
		if (password.length < 6) { 
			$('#result').removeClass()
			$('#result').addClass('short')
			return 'Too short' 
		}

		// Check if the password length is 8 characters or more, increase strength score...
		if (password.length > 7) strength += 1
		
		// Check if the password contains  both lower and uppercase characters, increase strength...
		if (password.match(/([a-z].*[A-Z])|([A-Z].*[a-z])/))  strength += 1
		
		// Check if the password contains numbers and characters, increase strength...
		if (password.match(/([a-zA-Z])/) && password.match(/([0-9])/))  strength += 1 
		
		// Check if the password contains one special character, increase strength...
		if (password.match(/([!,%,&,@,#,$,^,*,?,_,~])/))  strength += 1
		
		// Check if the password contains two special characters, increase strength...
		if (password.match(/(.*[!,%,&,@,#,$,^,*,?,_,~].*[!,%,&,@,#,$,^,*,?,_,~])/)) strength += 1
		
		if (strength < 2 ) {
            // If strength is less than 2...
			$('#result').removeClass()
			$('#result').addClass('weak')
			return 'Weak'			
		} else if (strength == 2 ) {
            // If strength is 2...
			$('#result').removeClass()
			$('#result').addClass('good')
			return 'Good'		
		} else {
            // If strength is greater than 2...
			$('#result').removeClass()
			$('#result').addClass('strong')
			return 'Strong'
		}
	}
});