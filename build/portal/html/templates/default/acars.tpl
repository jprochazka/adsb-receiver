{area:head/}
{area:contents}
            <div class="container">
                <h1>ACARS Messages</h1>
                <hr />
                {foreach page:acarsMessages as message}
                    <div>{message->Txt}</div>
                {/foreach}
            </div>
{/area}
{area:scripts}
        <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
{/area}