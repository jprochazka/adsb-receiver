{area:head/}
{area:contents}
            <div class="container">
                <h1>ACARS Messages</h1>
                <hr />
                {foreach page:acarsMessages as message}
                    <h2>{message->FlightNumber}<h2>
                    <p>
                        Aircarft Registration: {message->Registration}<br/>
                        The first message was received on {message->StartTime} with the last seen {message->LastTime}.<br/>
                        A total of {message->NbMessages} messages have been received by this flight.
                    </p>
                    <div>
                        <ul>
                            <li>Time: {message->Time}</li>
                            <li>Station ID: {message->IdStation}</li>
                            <li>Channel: {message->Channel}</li>
                            <li>Error: {message->Error}</li>
                            <li>Signal Level: {message->SignalLvl}</li>
                            <li>Mode: {message->Mode}</li>
                            <li>Ack: {message->Ack}</li>
                            <li>Label: {message->Label}</li>
                            <li>Block Number: {message->BlockNo}</li>
                            <li>Mesage Number: {message->MessNo}</li>
                            <li>Text: {message->Txt}</li>
                        </ul>
                    </div>
                {/foreach}
            </div>
{/area}
{area:scripts}
        <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
{/area}