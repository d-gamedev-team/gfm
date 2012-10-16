module gfm.common.httpclient;

/// Couldn't resist the urge to write a HTTP client

// TODO: pool TCP connections

import std.socketstream,
       std.stream,
       std.socket,
       std.string,
       std.conv,
       std.stdio;

import gfm.common.uri;

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

class HTTPClient
{
    public
    {
        this()
        {
            buffer.length = 4096;
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
        ubyte[] GET(URI uri)
        {
            checkURI(uri);
            return request(HTTPMethod.GET, uri.hostName(), uri.port(), uri.toString());
        }

        /// same as GET but without content
        void HEAD(URI uri)
        {
            checkURI(uri);
            request(HTTPMethod.HEAD, uri.hostName(), uri.port(), uri.toString());
        }

        /**
         * Perform a HTTP request.
         * requestURI can be "*", an absolute URI, an absolute path, or an authority
         * depending on the method.
         */
        ubyte[] request(HTTPMethod method, string host, int port, string requestURI)
        {
            ubyte[] res;

            try
            {
                connectTo(host, port);
                assert(_socket !is null);

                string request = format("%s %s HTTP/1.0\r\n"
                                        "Host: %s\r\n"
                                        "\r\n", GetHTTPMethodString(method), requestURI, host);
                auto scope ss = new SocketStream(_socket);
                ss.writeString(request);

                // skip headers
                while(true)
                {
                    auto line = ss.readLine();
                    writeln(line);
                    if (line.length == 0)
                        break;
                }

                while (!ss.eof())
                {
                    int read = ss.readBlock(buffer.ptr, buffer.length);
                    writefln("read %s bytes", read);
                    res ~= buffer[0..read];
                }
                writefln("%s", to!string(res));

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

        void connectTo(string host, int port)
        {
            if (_socket !is null)
            {
                _socket.close();
                _socket = null;
            }
            ushort uport = cast(ushort) port;
            _socket = new TcpSocket(new InternetAddress(host, uport));
        }

        static checkURI(URI uri)
        {
            if (uri.scheme() != "http")
                throw new HTTPException(format("'%' is not an HTTP absolute url", uri.toString()));
        }
    }
}

private
{
    string GetHTTPMethodString(HTTPMethod m)
    {
        final switch(m)
        {
            case HTTPMethod.OPTIONS: return "OPTIONS";
            case HTTPMethod.GET:     return "GET";
            case HTTPMethod.HEAD:    return "HEAD";
            case HTTPMethod.POST:    return "POST";
            case HTTPMethod.PUT:     return "PUT";
            case HTTPMethod.DELETE:  return "DELETE";
            case HTTPMethod.TRACE:   return "TRACE";
            case HTTPMethod.CONNECT: return "CONNECT";
        }
    }
}
