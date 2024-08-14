<?php
    session_start();

    // Load the require PHP classes.
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."account.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."links.class.php");

    $common = new common();
    $account = new account();
    $links = new links();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php");
    }

    $nameExists = FALSE;
    if ($common->postBack()) {
        // Check if the name already exists.
        $nameExists = $links->nameExists($_POST['name']);

        if (!$nameExists) {
            // Add this link..
            $links->addLink($_POST['name'], $_POST['address']);

            // Forward the user to the link management index page.
            header ("Location: /admin/links/");
        }
    }

    ////////////////
    // BEGIN HTML

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");
?>
            <h1>Links Management</h1>
            <hr />
            <h2>Add Link</h2>
            <form id="add-link" method="post" action="add.php">
                <div class="form-group">
                    <label for="name">Name</label>
                    <input type="text" id="name" name="name" class="form-control"<?php echo (isset($_POST['name']) ? ' value="'.$_POST['name'].'"' : '')?> required>
<?php
    if ($nameExists) {
?>
                    <div class="alert alert-danger" role="alert" id="failure-alert">
                        <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                            <span aria-hidden="true">&times;</span>
                        </button>
                        Name already exists.
                    </div>
<?php
    }
?>
                </div>
                <div class="form-group">
                    <label for="address">Address</label>
                    <input type="text" id="address" name="address" class="form-control"<?php echo (isset($_POST['address']) ? ' value="'.$_POST['address'].'"' : '')?> required>
                </div>
                <input type="submit" class="btn btn-default" value="Add">
            </form>
<?php
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>
