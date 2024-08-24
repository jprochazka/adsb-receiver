{area:head/}
{area:contents}
            <div class="container">
                <h1>Blog Posts</h1>
                <hr />
                {foreach page:blogPosts as post}
                <h2><a href="post.php?title={post->title}">{post->title}</a></h2>
                <p>Posted <strong>{post->date}</strong> by <strong>{post->author}</strong>.</p>
                <div>{post->contents}</div>
                {/foreach}
                <ul class="pagination">
                    {for pageNumber eq 1 to page:pageLinks}
                    <li><a href="blog.php?page={pageNumber}">{pageNumber}</a></li>
                    {/for}
                </ul>
            </div>
{/area}
{area:scripts/}
