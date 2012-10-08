module gfm.common.uri;

import std.range,
       std.array,
       std.string;

/**
 * Here is an attempt at implementing RFC 3986.
 *
 * All constructed URI are valid and normalized.
 *
 * TODO: parse IPvFuture
 */

// throw when an URI doesn't parse
class URIException : Exception
{
    public
    {
        this(string msg)
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
        // construct an URI from an input range, throw if invalid
        // input should be an ENCODED url range
        this(T)(T input) if (isForwardRange!T)
        {
            _scheme = null;
            _hostName = null;
            _port = -1;
            _userInfo = null;
            _path = null;
            _query = null;
            _fragment = null;
            parseURI(input);
        }

        // test for URI validity
        static bool isValid(T)(T input) pure /* nothrow */
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

        // normalized URI components
        pure const nothrow
        {
            /// return scheme, guaranteed not null
            string scheme()
            {
                return _scheme;
            }

            /// return hostName, or null if not available
            string hostName()
            {
                return _hostName;
            }

            /// return port number, or -1 if not available
            int port()
            {
                return _port;
            }

            /// return the user-info part of the URI, or null if not available
            string userInfo()
            {
                return _userInfo;
            }

            /// return the path part of the URI, never null, can be the empty string
            string path()
            {
                return _path;
            }

            /// return the query part of the URI, or null if not available
            string query()
            {
                return _query;
            }

            /// return the fragment part of the URI, or null if not available
            string fragment()
            {
                return _fragment;
            }
        }
    }

    private
    {
        // normalized URI components
        string _scheme;
        string _userInfo;
        string _hostName;
        int _port;
        string _path;
        string _query;
        string _fragment;

        // URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
        void parseURI(T)(ref T input)
        {
            _scheme = parseScheme(input);

            if (popChar(input) != ':')
                throw new URIException("expected colon character in URL");

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

            char c = popChar(input);
            if (c == '/')
            {
                T sinput = input.save;
                consume(input, '/');
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
                T sinput = input.save;
                try
                {
                    _path = parsePathNoScheme(input);
                }
                catch(URIException e)
                {
                    input = sinput.save;
                    _path = parsePathNoScheme(input);
                }
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

            parseHost(input);

            if (peekChar(input) == ':')
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

        string parseHost(T)(ref T input)
        {
            char c = peekChar(input);
            if (c == '[')
                return parseIPLiteral(input);
            else
            {
                T iinput = input.save;
                try
                {
                    return parseIPv4Address(input);
                }
                catch (URIException e)
                {
                    input = iinput.save;
                    return parseRegName(input);
                }
            }
        }

        string parseIPLiteral(T)(ref T input)
        {
            string res;
            consume(input, '[');
            if (peekChar(input) == 'v')
                throw new URIException("unsupported future IP addresses in URI parsing");
            else
                res = parseIPv6Address(input);
            consume(input, ']');
            return res;
        }

        string parseIPv6Address(T)(ref T input)
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
            if (popChar(input) != '%')
                throw new URIException("expected character %");

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
                res ~= parseSegment(input, true, true);
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
}

unittest
{
    struct Test
    {
        string uri;
        string scheme;
    }

    auto wellFormedURIs =
    [
        Test("HTTP://fr.wikipedia.org/wiki/Uniform_Resource_Locator", "http"),
        Test("ftp://ftp.rfc-editor.org/in-notes/rfc2396.txt", "ftp"),
        Test("mailto:Quidam.no-spam@example.com", "mailto"),
        Test("news:fr.comp.infosystemes.www.auteurs", "news"),
        Test("gopher://gopher.quux.org/", "gopher"),
        Test("http://Jojo:lApIn@www.example.com:8888/chemin/d/acc%C3%A8s.php?q=req&q2=req2#signet", "http"),
        Test("ldap://[2001:db8::7]/c=GB?objectClass?one", "ldap"),
        Test("mailto:John.Doe@example.com", "mailto"),
        Test("tel:+1-816-555-1212", "tel"),
        Test("telnet://192.0.2.16:80/", "telnet"),
        Test("urn:oasis:names:specification:docbook:dtd:xml:4.1.2", "urn"),
    ];

    foreach (test; wellFormedURIs)
    {
        bool valid = URI.isValid(test.uri);
        assert(valid);
        auto uri = new URI(test.uri);
        assert(uri.scheme() == test.scheme);
    }
}
