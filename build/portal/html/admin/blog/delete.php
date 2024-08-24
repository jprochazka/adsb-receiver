<?php
    session_start();

    // Load the require PHP classes.
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."account.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."blog.class.php");

    $common = new common();
    $account = new account();
    $blog = new blog();

    // Check if the user is logged in.
    if (!$account->isAuthenticated()) {
        // The user is not logged in so forward them to the login page.
        header ("Location: login.php");
    }

    if ($common->postBack()) {
        // Delete the selected blog post.
        $blog->deletePostByTitle(urldecode($_GET['title']));

        // Forward the user to the blog management index page.
        header ("Location: /admin/blog/");
    }

    // Get titles and dates for all blog posts.
    $post = $blog->getPostByTitle(urldecode($_GET['title']));

    // Properly format the date and convert to slected time zone.
    $date = new DateTime($post['date'], new DateTimeZone('UTC'));
    $date->setTimezone(new DateTimeZone($common->getSetting('timeZone')));
    $postDate = $date->format($common->getSetting('dateFormat'));

    ////////////////
    // BEGIN HTML

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."header.inc.php");
?>
            <h1>Blog Management</h1>
            <hr />
            <h2>Delete Blog Post</h2>
            <h3><?php echo $post['title']; ?></h3>
            <p>Posted <strong><?php echo $postDate; ?></strong> by <strong><?php echo $common->getAdminstratorName($post['author']); ?></strong>.</p>
            <div class="alert alert-danger" role="alert">
                <p>
                    <strong>Confirm Delete</strong><br />
                    Are you sure you want to delete this blog post?
                </p>
            </div>
            <form id="delete-blog-post" method="post" action="delete.php?title=<?php echo urlencode($post['title']); ?>">
                <input type="submit" class="btn btn-default" value="Delete Post">
                <a href="/admin/blog/" class="btn btn-info" role="button">Cancel</a>
            </form>
<?php
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."admin".DIRECTORY_SEPARATOR."includes".DIRECTORY_SEPARATOR."footer.inc.php");
?>
