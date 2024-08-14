<?php
    session_start();

    $passwordIncorrect = FALSE;
    $didNotMatch = FALSE;

    // Load the require PHP classes.
    require_once('../classes/common.class.php');
    require_once('../classes/account.class.php');
    require_once('../classes/settings.class.php');

    $common = new common();
    $account = new account();
    $settings = new settings();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php?origin=".urlencode('account.php'));
    }

    // Set updated variable to FALSE.
    $updated = FALSE;

    if ($common->postBack()) {
        // Check that a name was supplied.
        $nameSupplied = FALSE;
        if (!empty($_POST['name']))
            $nameSupplied = TRUE;

        // Check that a vailid email address was supplied.
        $validEmail = FALSE;
        if (filter_var($_POST['email'], FILTER_VALIDATE_EMAIL))
            $validEmail = TRUE;

        // If the current password was supplied process a password change.
        $passwordChanged = FALSE;
        if (!empty($_POST['password'])) {
            // Check the length of the password.
            $tooShort = TRUE;
            if (isset($_POST['password1']) && strlen($_POST['password1']) >= $settings::sec_length)
                $tooShort = FALSE;

            // Check that the supplied new passwords match.
            $notMatching = TRUE;
            if ($_POST['password1'] == $_POST['password2'])
                $notMatching = FALSE;

            // Check that the supplied current password matches that which is stored.
            $authenticated = $account->authenticate($_SESSION['login'], $_POST['password'], FALSE, FALSE);

            // If everything associated with passwords is validated change the password.
            if (!$tooShort && !$notMatching && $authenticated) {
                // Change the password stored in administrators.xml related to this users login.
                $account->changePassword($_SESSION['login'], password_hash($_POST['password1'], PASSWORD_DEFAULT));
                $passwordChanged = TRUE;
            }
        }

        // If validation passed make the requested changes to the administrator account data.
        if ($nameSupplied && $validEmail) {
            $account->changeName($_SESSION['login'], $_POST['name']);
            $account->changeEmail($_SESSION['login'], $_POST['email']);
            $updated = TRUE;
        }

        // Since the password has changed we will log the user out to clear older session variables.
        if ($passwordChanged) {
            $account->logout();
        }
    }

    require_once('includes/header.inc.php');

    /////////////////////
    // BEGIN HTML BODY //

    // Display the updated message if settings were updated.
    if ($updated) {
?>
        <div id="settings-saved" class="alert alert-success fade in" role="alert">
            <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
            Changes to your account have been saved.
        </div>
<?php
    }
?>
        <h1>Account Management</h1>
        <hr />
<?php
    if ($passwordIncorrect || $didNotMatch) {
?>
            <div id="failure-alert" class="alert alert-danger" role="alert">
                <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
                <?php ($noName ? print "You must supply a name to associate with this account.<br />" : ''); ?>
                <?php ($invalidEmail ? print "You must supply a valid email address to associate with this account.<br />" : ''); ?>
                <?php ($passwordIncorrect || $noCurrent ? print "You did not supply the correct current password for this account.<br />" : ''); ?>
                <?php ($tooShort ? print "Your password must be at least ".$settings::sec_length." characters long.<br />" : ''); ?>
                <?php ($notMatching || $passwordMissing ? print "The password and password confirmation did not match or are missing.<br />" : ''); ?>
            </div>
<?php
    }
?>
        <form id="account-form" method="post" action="account.php">

            <div class="panel panel-default">
                <div class="panel-heading">Account Settings</div>
                <div class="panel-body">
                    <div class="form-group">
                        <input type="text" class="form-control" name="login" id="login" placeholder="Login" value="<?php echo $_SESSION['login']; ?>" disabled>
                    </div>
                    <div class="form-group">
                        <input type="text" class="form-control" name="name" id="name" placeholder="Name" value="<?php echo $account->getName($_SESSION['login']); ?>" required>
                    </div>
                    <div class="form-group">
                        <input type="email" class="form-control" name="email" id="email" placeholder="Email Address" value="<?php echo $account->getEmail($_SESSION['login']); ?>" required>
                    </div>
                </div>
            </div>

            <div class="panel panel-default">
                <div class="panel-heading">Change Password</div>
                <div class="panel-body">
                    <div class="form-group">
                        <input type="password" class="form-control" name="password" id="password" placeholder="Current Password">
                    </div>
                    <div class="form-group">
                        <input type="password" class="form-control" name="password1" id="password1" placeholder="New Password" required>
                    </div>
                    <div class="form-group">
                        <input type="password" class="form-control" name="password2" id="password2" placeholder="Confirm Password" required>
                    </div>
                </div>
            </div>

            <input type="submit" class="btn btn-default" value="Submit">
        </form>
<?php

    // END HTML BODY //
    ///////////////////

    require_once('includes/footer.inc.php');
?>
