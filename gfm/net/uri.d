module gfm.net.uri;

import std.range,
       std.string,
       std.ascii,
       std.socket;

/**
 * Here is an attempt at implementing RFC 3986.
 *
 * All constructed URI are valid and normalized.
 *
 * TODO: separate segments in parsed form -> relative URL combining
 *       . and .. normalization
 */

// throw when an URI doesn't parse
class URIException : Exception
{
    public
    {
        this(string msg) pure
        {
            super(msg);
        }
    }
}

/// Parsed URI wrapper
class URI
{
    public
    {
        enum HostType
        {
            NONE,
            REG_NAME, // registered name to be used with DNS
            IPV4,
            IPV6,
            IPVFUTURE
        }

        // construct an URI from an input range, throw if invalid
        // input should be an ENCODED url range
        this(T)(T input) if (isForwardRange!T)
        {
            _scheme = null;
            _hostType = HostType.NONE;
            _hostName = null;            
            _port = -1;
            _userInfo = null;
            _path = null;
            _query = null;
            _fragment = null;
            parseURI(input);
        }

        // test for URI validity
        static bool isValid(T)(T input) /* pure */ nothrow
        {
            try
            {
                try
                {
                    URI uri = new URI(input); 
                    return true;
                }
                catch (URIException e)
                {
                    return false;
                }
            }
            catch (Exception e)
            {
                assert(false); // came here? Fix the library by writing the missing catch-case.
                return false;
            }
        }

        // getters for normalized URI components

        /// return scheme, guaranteed not null
        string scheme() pure const nothrow
        {
            return _scheme;
        }

        /// return hostName, or null if not available
        string hostName() pure const nothrow
        {
            return _hostName;
        }

        /// return host type (HostType.NONE if not available)
        HostType hostType() pure const nothrow
        {
            return _hostType;
        }

        /** 
         * Return port number. 
         * If none is provided by the URI, return the default port for this scheme.
         * if the scheme isn't recognized, return -1.
         */
        int port() pure const nothrow
        {
            if (_port != -1)
                return _port;

            foreach (ref e; knownSchemes)
                if (e.scheme == _scheme)
                    return e.defaultPort;

            return -1;
        }

        /// return the user-info part of the URI, or null if not available
        string userInfo() pure const nothrow
        {
            return _userInfo;
        }

        /// return the path part of the URI, never null, can be the empty string
        string path() pure const nothrow
        {
            return _path;
        }

        /// return the query part of the URI, or null if not available
        string query() pure const nothrow
        {
            return _query;
        }

        /// return the fragment part of the URI, or null if not available
        string fragment() pure const nothrow
        {
            return _fragment;
        }

        /// get authority part of the URI
        string authority() pure const nothrow
        {
            if (_hostName is null)
                return null;

            string res = "";
            if (_userInfo !is null)
                res = res ~ _userInfo ~ "@"; 
            res ~= _hostName;
            if (_port != -1)
                res = res ~ ":" ~ itos(_port);
            return res;
        }

        /// getting a std.socket.Address from the URI
        Address address()
        {
            final switch(_hostType)
            {
                case HostType.REG_NAME:
                case HostType.IPV4:
                    return new InternetAddress(_hostName, cast(ushort)port());

                case HostType.IPV6:
                    return new Internet6Address(_hostName, cast(ushort)port());

                case HostType.IPVFUTURE:
                case HostType.NONE:
                    throw new URIException("Cannot resolve such host");
            }
        }

        override string toString() const
        {
            string res = _scheme ~ ":";

            if (_hostName is null)            
                res = res ~ "//" ~ authority();
            res ~= _path;
            if (_query !is null)
                res = res ~ "?" ~ _query;
            if (_fragment !is null)
                res = res ~ "#" ~ _fragment;
            return res;
        }

        // Two URIs are equals if they have the same normalized string representation
        bool opEquals(U)(U other) pure const nothrow if (is(U : FixedPoint))
        {
            return value == other.value;
        }
    }

    private
    {
        // normalized URI components
        string _scheme;     // never null, never empty
        string _userInfo;   // can be null
        HostType _hostType; // what the hostname string is (NONE if no host in URI)
        string _hostName;   // null if no authority in URI
        int _port;          // -1 if no port in URI
        string _path;       // never null, bu could be empty
        string _query;      // can be null
        string _fragment;   // can be null

        // URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
        void parseURI(T)(ref T input)
        {
            _scheme = toLower(parseScheme(input));
            consume(input, ':');
            parseHierPart(input);

            if (input.empty)
                return;

            char c = popChar(input);

            if (c == '?')
            {
                _query = parseQuery(input);

                if (input.empty)
                    return;

                c = popChar(input);
            }

            if (c == '#')
            {
                _fragment = parseFragment(input);
            }

            if (!input.empty)
                throw new URIException("unexpected characters at end of URI");
        }

        string parseScheme(T)(ref T input)
        {
            string result = "";
            char c = popChar(input);
            if (!isAlpha(c))
                throw new URIException("expected alpha character in URI scheme");

            result ~= c;

            while(!input.empty)
            {
                c = peekChar(input);

                if (isAlpha(c) || isDigit(c) || "+-.".contains(c))
                {
                    result ~= c;
                    input.popFront();
                }
                else
                    break;
            }
            return result;
        }

        // hier-part   = "//" authority path-abempty
        //             / path-absolute
        //             / path-rootless
        //             / path-empty
        void parseHierPart(T)(ref T input)
        {
            if (input.empty())
                return; // path-empty

            char c = peekChar(input);
            if (c == '/')
            {
                input.popFront();
                T sinput = input.save;
                if (!input.empty() && peekChar(input) == '/')
                {
                    consume(input, '/');
                    parseAuthority(input);
                    _path = parseAbEmpty(input);
                }
                else
                {
                    input = sinput.save;
                    _path = parsePathAbsolute(input);
                }
            }
            else
            {
                _path = parsePathRootless(input);
            }
        }

        // authority   = [ userinfo "@" ] host [ ":" port ]
        void parseAuthority(T)(ref T input)
        {
            // trying to parse user
            T uinput = input.save;
            try
            {
                _userInfo = parseUserinfo(input);
                consume(input, '@');
            }
            catch(URIException e)
            {
                // no user name in URI
                _userInfo = null;
                input = uinput.save;
            }

            parseHost(input, _hostName, _hostType);

            if (!empty(input) && peekChar(input) == ':')
            {
                consume(input, ':');
                _port = parsePort(input);
            }
        }

        string parsePcharString(T)(ref T input, bool allowColon, bool allowAt, bool allowSlashQuestionMark)
        {
            string res = "";

            while(!input.empty)
            {
                char c = peekChar(input);

                if (isUnreserved(c) || isSubDelim(c))
                    res ~= popChar(input);
                else if (c == '%')
                    res ~= parsePercentEncodedChar(input);
                else if (c == ':' && allowColon)
                    res ~= popChar(input);
                else if (c == '@' && allowAt)
                    res ~= popChar(input);
                else if ((c == '?' || c == '/') && allowSlashQuestionMark)
                    res ~= popChar(input);
                else
                    break;
            }
            return res;
        }

        
        void parseHost(T)(ref T input, out string res, out HostType hostType)
        {
            char c = peekChar(input);
            if (c == '[')
                parseIPLiteral(input, res, hostType);
            else
            {
                T iinput = input.save;
                try
                {
                    hostType = HostType.IPV4;
                    res = parseIPv4Address(input);
                }
                catch (URIException e)
                {
                    input = iinput.save;
                    hostType = HostType.REG_NAME;
                    res = toLower(parseRegName(input));
                }
            }
        }

        void parseIPLiteral(T)(ref T input, out string res, out HostType hostType)
        {
            consume(input, '[');
            if (peekChar(input) == 'v')
            {
                hostType = HostType.IPVFUTURE;
                res = parseIPv6OrFutureAddress(input);
            }
            else
            {
                hostType = HostType.IPV6;
                string ipv6 = parseIPv6OrFutureAddress(input);

                // validate and expand IPv6 (for normalizaton to be effective for comparisons)
                try
                {
                    ubyte[16] bytes = Internet6Address.parse(ipv6);
                    res = "";
                    foreach (i ; 0..16)
                    {
                        if ((i & 1) == 0 && i != 0) 
                            res ~= ":";
                        res ~= format("%02x", bytes[i]);
                    }
                }
                catch(SocketException e)
                {
                    // IPv6 address did not parse
                    throw new URIException(e.msg);
                }
            }
            consume(input, ']');
        }

        string parseIPv6OrFutureAddress(T)(ref T input)
        {
            string res = "";
            while (peekChar(input) != ']')
                res ~= popChar(input);
            return res;
        }

        string parseIPv4Address(T)(ref T input)
        {
            int a = parseDecOctet(input);
            consume(input, '.');
            int b = parseDecOctet(input);
            consume(input, '.');
            int c = parseDecOctet(input);
            consume(input, '.');
            int d = parseDecOctet(input);
            return format("%s.%s.%s.%s", a, b, c, d);
        }        

        // dec-octet     = DIGIT                 ; 0-9
        //               / %x31-39 DIGIT         ; 10-99
        //               / "1" 2DIGIT            ; 100-199
        //               / "2" %x30-34 DIGIT     ; 200-249
        //               / "25" %x30-35          ; 250-255
        int parseDecOctet(T)(ref T input)
        {
            int res = popDigit(input);

            if (!input.empty && isDigit(peekChar(input)))
            {
                res = 10 * res + popDigit(input);

                if (!input.empty && isDigit(peekChar(input)))
                    res = 10 * res + popDigit(input);
            }

            if (res > 255)
                throw new URIException("out of range number in IPv4 address");

            return res;
        }

        // query         = *( pchar / "/" / "?" )
        string parseQuery(T)(ref T input)
        {
            return parsePcharString(input, true, true, true);
        }

        // fragment      = *( pchar / "/" / "?" )
        string parseFragment(T)(ref T input)
        {
            return parsePcharString(input, true, true, true);
        }

        // pct-encoded   = "%" HEXDIG HEXDIG
        char parsePercentEncodedChar(T)(ref T input)
        {
            consume(input, '%');

            int char1Val = hexValue(popChar(input));
            int char2Val = hexValue(popChar(input));
            return cast(char)(char1Val * 16 + char2Val);
        }

        // userinfo      = *( unreserved / pct-encoded / sub-delims / ":" )
        string parseUserinfo(T)(ref T input)
        {
            return parsePcharString(input, true, false, false);
        }

        // reg-name      = *( unreserved / pct-encoded / sub-delims )
        string parseRegName(T)(ref T input)
        {
            return parsePcharString(input, false, false, false);
        }

        // port          = *DIGIT
        int parsePort(T)(ref T input)
        {
            int res = 0;

            while(!input.empty)
            {
                char c = peekChar(input);
                if (!isDigit(c))
                    break;
                res = res * 10 + popDigit(input);
            }
            return res;
        }

        // segment       = *pchar
        // segment-nz    = 1*pchar
        // segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )
        string parseSegment(T)(ref T input, bool allowZero, bool allowColon)
        {
            string res = parsePcharString(input, allowColon, true, false);
            if (!allowZero && res == "")
                throw new URIException("expected a non-zero segment in URI");
            return res;
        }

        // path-abempty  = *( "/" segment )
        string parseAbEmpty(T)(ref T input)
        {
            string res = "";
            while (!input.empty)
            {
                if (peekChar(input) != '/')
                    break;
                consume(input, '/');
                res = res ~ "/" ~ parseSegment(input, true, true);
            }
            return res;
        }

        // path-absolute = "/" [ segment-nz *( "/" segment ) ]
        string parsePathAbsolute(T)(ref T input)
        {
            consume(input, '/');
            string res = "/";

            try
            {
                res ~= parseSegment(input, false, true);
            }
            catch(URIException e)
            {
                return res;
            }

            res ~= parseAbEmpty(input);
            return res;
        }

        string parsePathNoSlash(T)(ref T input, bool allowColonInFirstSegment)
        {
            string res = parseSegment(input, false, allowColonInFirstSegment);
            res ~= parseAbEmpty(input);
            return res;
        }

        // path-noscheme = segment-nz-nc *( "/" segment )
        string parsePathNoScheme(T)(ref T input)
        {
            return parsePathNoSlash(input, false);
        }

        // path-rootless = segment-nz *( "/" segment )
        string parsePathRootless(T)(ref T input)
        {
            return parsePathNoSlash(input, true);
        }
    }
}

private pure
{
    bool contains(string s, char c) nothrow
    {
        foreach(char sc; s)
          if (c == sc)
            return true;
        return false;
    }

    bool isAlpha(char c) nothrow
    {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
    }

    bool isDigit(char c) nothrow
    {
        return c >= '0' && c <= '9';
    }

    bool isHexDigit(char c) nothrow
    {
        return hexValue(c) != -1;
    }

    bool isUnreserved(char c) nothrow
    {
        return isAlpha(c) || isDigit(c) || "-._~".contains(c);
    }

    bool isReserved(char c) nothrow
    {
        return isGenDelim(c) || isSubDelim(c);
    }

    bool isGenDelim(char c) nothrow
    {
        return ":/?#[]@".contains(c);
    }

    bool isSubDelim(char c) nothrow
    {
        return "!$&'()*+,;=".contains(c);
    }

    int hexValue(char c) nothrow
    {
        if (isDigit(c))
            return c - '0';
        else if (c >= 'a' && c <= 'f')
            return c - 'a';
        else if (c >= 'A' && c <= 'F')
            return c - 'A';
        else
            return -1;
    }

    // peek char from input range, or throw
    char peekChar(T)(ref T input)
    {
        if (input.empty())
            throw new URIException("expected character");

        dchar c = input.front;

        if (cast(int)c >= 127)
            throw new URIException("US-ASCII character expected");

        return cast(char)c;
    }

    // pop char from input range, or throw
    char popChar(T)(ref T input)
    {
        char result = peekChar(input);
        input.popFront();
        return result;
    }

    int popDigit(T)(ref T input)
    {
        char c = popChar(input);
        if (!isDigit(c))
            throw new URIException("expected digit character");
        return hexValue(c);
    }

    void consume(T)(ref T input, char expected)
    {
        char c = popChar(input);
        if (c != expected)
            throw new URIException("expected '" ~ c ~ "' character");
    }

    string itos(int i) pure nothrow
    {
        string res = "";
        do
        {
            res = ('0' + (i % 10)) ~ res;
            i = i / 10;
        } while (i != 0);
        return res;
    }

    struct KnownScheme
    {
        string scheme;
        int defaultPort;
    }

    enum knownSchemes =
    [
        KnownScheme("ftp", 21),
        KnownScheme("sftp", 22),
        KnownScheme("telnet", 23),
        KnownScheme("smtp", 25),
        KnownScheme("gopher", 70),
        KnownScheme("http", 80),
        KnownScheme("nntp", 119),
        KnownScheme("https", 443)
    ];

}

unittest
{
    
    {
        string s = "HTTP://machin@fr.wikipedia.org:80/wiki/Uniform_Resource_Locator?Query%20Part=4#fragment%20part";
        assert(URI.isValid(s));
        auto uri = new URI(s);
        assert(uri.scheme() == "http");
        assert(uri.userInfo() == "machin");
        assert(uri.hostName() == "fr.wikipedia.org");
        assert(uri.port() == 80);
        assert(uri.authority() == "machin@fr.wikipedia.org:80");
        assert(uri.path() == "/wiki/Uniform_Resource_Locator");
        assert(uri.query() == "Query Part=4");
        assert(uri.fragment() == "fragment part");
    }

    // host tests
    {
        assert((new URI("http://truc.org")).hostType() == URI.HostType.REG_NAME);
        assert((new URI("http://127.0.0.1")).hostType() == URI.HostType.IPV4);
        assert((new URI("http://[2001:db8::7]")).hostType() == URI.HostType.IPV6);
        assert((new URI("http://[v9CrazySchemeFromOver9000year]")).hostType() == URI.HostType.IPVFUTURE);
    }

    auto wellFormedURIs =
    [
        "ftp://ftp.rfc-editor.org/in-notes/rfc2396.txt",
        "mailto:Quidam.no-spam@example.com",
        "news:fr.comp.infosystemes.www.auteurs",
        "gopher://gopher.quux.org/",
        "http://Jojo:lApIn@www.example.com:8888/chemin/d/acc%C3%A8s.php?q=req&q2=req2#signet",
        "ldap://[2001:db8::7]/c=GB?objectClass?one",
        "mailto:John.Doe@example.com",
        "tel:+1-816-555-1212",
        "telnet://192.0.2.16:80/",
        "urn:oasis:names:specification:docbook:dtd:xml:4.1.2",
        "about:",
    ];

    foreach (wuri; wellFormedURIs)
    {
        bool valid = URI.isValid(wuri);
        assert(valid);
    }
}
