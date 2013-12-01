import gfm.net.all;

import std.stdio;

// Print the result of a GET request

void main(string args[])
{
    if (args.length != 2)
    {
        writefln("Usage: simplehttp http://www.myurl.com");
        writefln("       Print the result of a GET request.");

        return;
    }

    string url = args[1];

    scope auto client = new HTTPClient();
    HTTPResponse response = client.GET(new URI(url));

    // Write headers
    writefln("%s returned error code %s", url, response.statusCode );

    foreach (string header, value; response.headers)
    {
        writefln("%s: %s", header, value);
    }

    writefln("Body: \n");
    writefln("%s", response.content);
}
