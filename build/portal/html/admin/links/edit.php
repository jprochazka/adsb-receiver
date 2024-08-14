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

    if ($common->postBack()) {
        // Update the contents of the blog post.
        $links->editLinkByName(urldecode($_POST['originalName']), $_POST['name'], $_POST['address']);

        // Forward the user to the link management index page.
        header ("Location: /admin/links/");
    }

    // Get the link data.
    $link = $links->getLinkByName(urldecode($_GET['name']));

    ////////////////
    // BEGIN HTML

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");
?>
            <h1>Links Management</h1>
            <hr />
            <h2>Edit Link</h2>
            <h3><?php echo $link['name']; ?></h3>
            <form id="edit-link" method="post" action="edit.php">
                <div class="form-group">
                    <label for="name">Name</label>
                    <input type="text" id="name" name="name" class="form-control" value="<?php echo $link['name']; ?>" required>
                </div>
                <div class="form-group">
                    <label for="address">Address</label>
                    <input type="text" id="address" name="address" class="form-control" value="<?php echo $link['address']; ?>" required>
                </div>
                <input type="hidden" name="originalName" value="<?php echo $link['name']; ?>">
                <input type="submit" class="btn btn-default" value="Commit Changes">
            </form>
<?php
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>

