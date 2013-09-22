module gfm.core.text;

import std.file,
       std.utf,
       std.conv,
       std.encoding,
       std.array,
       std.c.string;

import gfm.core.log;

string[] readTextFile(string filename)
{
    try
    {
        string data = readText(filename);
        return [data];
    }
    catch(FileException e)
    {
        return [];
    }
    catch(UTFException e)
    {
        return [];
    }    
}

/// Read a C string and return a sanitized utf-8 string.
/// Used when interfacing with C libraries which may output anything.
string sanitizeUTF8(const(char*) inputZ)
{
    return sanitizeUTF8(inputZ, null, null);
}

/// Same but warns when invalid unicode is found
string sanitizeUTF8(const(char*) inputZ, Log log, string source)
{
    assert(inputZ != null);
    size_t inputLength = strlen(inputZ);

    auto result = appender!string();
    result.reserve(inputLength);

    bool foundInvalid = false;

    size_t i = 0;
    while(i < inputLength)
    {
        dchar ch = inputZ[i];
        try
        {
            ch = std.utf.decode(cast(string)inputZ[0..inputLength], i);
        }
        catch(UTFException)
        { 
            foundInvalid = true;
            ++i; 
        }    
        char[4] dst;
        auto len = std.utf.encode(dst, ch);
        result.put(dst[0 .. len]);
    }

    // optionally, warn that input had invalid UTF-8
    if (foundInvalid && log !is null)
        log.warnf("got invalid UTF-8 sequence from %s", source);

    return result.data;
}

