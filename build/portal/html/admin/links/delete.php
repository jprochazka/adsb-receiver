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
        // Delete the selected link.
        $links->deleteLinkByName(urldecode($_GET['name']));

        // Forward the user to the link management index page.
        header ("Location: /admin/links/");
    }

    // Get the data for this link.
    $link = $links->getLinkByName(urldecode($_GET['name']));

    ////////////////
    // BEGIN HTML

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");
?>
            <h1>Links Management</h1>
            <hr />
            <h2>Delete Link</h2>
            <h3><?php echo $link['name']; ?></h3>
            <p>With the address of <strong><?php echo $link['address']; ?></strong>.</p>
            <div class="alert alert-danger" role="alert">
                <p>
                    <strong>Confirm Delete</strong><br />
                    Are you sure you want to delete this link?
                </p>
            </div>
            <form id="delete-link" method="post" action="delete.php?name=<?php echo urlencode($link['name']); ?>">
                <input type="submit" class="btn btn-default" value="Delete Link">
                <a href="/admin/links/" class="btn btn-info" role="button">Cancel</a>
            </form>
<?php
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>
