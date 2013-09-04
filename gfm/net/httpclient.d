module gfm.net.httpclient;

/// Couldn't resist the urge to write a HTTP client

// TODO: pool TCP connections

import std.socketstream,
       std.stream,
       std.socket,
       std.string,
       std.conv,
       std.stdio;

import gfm.net.uri;

class HTTPException : Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
        }
    }
}

enum HTTPMethod
{
    OPTIONS,
    GET,
    HEAD,
    POST,
    PUT,
    DELETE,
    TRACE,
    CONNECT
}

class HTTPResponse
{
    int statusCode;
    string[string] headers;
    ubyte[] content;
}

class HTTPClient
{
    public
    {
        this(string userAgent = "gfm-http-client")
        {
            buffer.length = 4096;
            _userAgent = userAgent;
        }

        ~this()
        {
            close();
        }

        void close()
        {
            if (_socket !is null)
            {
                _socket.close();
                _socket = null;
            }
        }

        /// From an absolute HTTP url, return content.
        HTTPResponse GET(URI uri)
        {

            return request(HTTPMethod.GET, uri, defaultHeaders(uri));
        }

        /// same as GET but without content
        HTTPResponse HEAD(URI uri)
        {
            return request(HTTPMethod.HEAD, uri, defaultHeaders(uri));
        }

        /**
         * Perform a HTTP request.
         * requestURI can be "*", an absolute URI, an absolute path, or an authority
         * depending on the method.
         */
        HTTPResponse request(HTTPMethod method, URI uri, string[string] headers)
        {
            checkURI(uri);
            auto res = new HTTPResponse();


            try
            {
                connectTo(uri);
                assert(_socket !is null);

                string request = format("%s %s HTTP/1.0\r\n", to!string(method), uri.toString());

                foreach (header; headers.byKey())
                {
                    request ~= format("%s: %s\r\n", header, headers[header]);
                }
                 request ~= "\r\n";

                auto scope ss = new SocketStream(_socket);
                ss.writeString(request);

                // parse status line
                auto line = ss.readLine();
                if (line.length < 12 || line[0..5] != "HTTP/" || line[6] != '.')
                    throw new HTTPException("Cannot parse HTTP status line");

                if (line[5] != '1' || (line[7] != '0' && line[7] != '1'))
                    throw new HTTPException("Unsupported HTTP version");

                // parse error code
                res.statusCode = 0;
                for (int i = 0; i < 3; ++i)
                {
                    char c = line[9 + i];
                    if (c >= '0' && c <= '9')
                        res.statusCode = res.statusCode * 10 + (c - '0');
                    else
                        throw new HTTPException("Expected digit in HTTP status code");
                }

                // parse headers
                while(true)
                {
                    auto headerLine = ss.readLine();

                    if (headerLine.length == 0)
                        break;

                    sizediff_t colonIdx = indexOf(headerLine, ':');
                    if (colonIdx == -1)
                        throw new HTTPException("Cannot parse HTTP header: missing colon");

                    string key = headerLine[0..colonIdx].idup;

                    // trim leading spaces and tabs
                    sizediff_t valueStart = colonIdx + 1;
                    for ( ; valueStart <= headerLine.length; ++valueStart)
                    {
                        char c = headerLine[valueStart];
                        if (c != ' ' && c != '\t')
                            break;
                    }

                    // trim trailing spaces and tabs
                    sizediff_t valueEnd = headerLine.length;
                    for ( ; valueEnd > valueStart; --valueEnd)
                    {
                        char c = headerLine[valueEnd - 1];
                        if (c != ' ' && c != '\t')
                            break;
                    }

                    string value = headerLine[valueStart..valueEnd].idup;
                    res.headers[key] = value;
                }

                while (!ss.eof())
                {
                    int read = cast(int)( ss.readBlock(buffer.ptr, buffer.length));
                    res.content ~= buffer[0..read];
                }

                return res;
            }
            catch (Exception e)
            {
                throw new HTTPException(e.msg);
            }
        }
    }

    private
    {
        TcpSocket _socket;
        ubyte[] buffer;
        string _userAgent;

        void connectTo(URI uri)
        {
            if (_socket !is null)
            {
                _socket.close();
                _socket = null;
            }
            _socket = new TcpSocket(uri.address());
        }

        static checkURI(URI uri)
        {
            if (uri.scheme() != "http")
                throw new HTTPException(format("'%' is not an HTTP absolute url", uri.toString()));
        }

        string[string] defaultHeaders(URI uri)
        {
            string hostName = uri.hostName();
            auto headers = ["Host": hostName, 
                            "User-Agent": _userAgent];
            return headers;
        }
    }
}

