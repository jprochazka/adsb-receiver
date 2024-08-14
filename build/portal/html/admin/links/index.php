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

    // Get all links.
    $links = $links->getAllLinks();

    ////////////////
    // BEGIN HTML

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");
?>

            <h1>Links Management</h1>
            <hr />
            <h2>Links</h2>
            <a href="add.php" class="btn btn-info" style="margin-bottom:  10px;" role="button">Add Link</a>
            <div class="table-responsive">
                <table class="table table-striped table-condensed">
                    <tr>
                        <th></th>
                        <th>Name</th>
                        <th>Address</th>
                    </tr>
<?php
    foreach ($links as $link) {
?>
                    <tr>
                        <td><a href="edit.php?name=<?php echo urlencode($link['name']); ?>">edit</a> <a href="delete.php?name=<?php echo urlencode($link['name']); ?>">delete</a></td>
                        <td><?php echo $link['name']; ?></td>
                        <td><a href="<?php echo $link['address']; ?>" target="_blank"><?php echo $link['address']; ?></a></td>
                    </tr>
<?php
    }
?>
                </table>
            </div>
<?php
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>
