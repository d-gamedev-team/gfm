import gfm.net.all;


void main()
{
    auto client = new HTTPClient();
    HTTPResponse response = client.GET(new URI("http://google.com"));
}
