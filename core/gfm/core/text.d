module gfm.core.text;

import std.file,
       std.utf,
       std.conv,
       std.encoding,
       std.array,
       std.c.string;

import std.logger;


/// Reads a text file at once.
/// Bugs: Remove in favor of std.file.read.
//        This means shaders must compile from a single string instead of string[].
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

/// Sanitize a C string from a library.
/// Returns: Sanitized UTF-8 string. Invalid UTF-8 sequences are replaced by question marks.
string sanitizeUTF8(const(char*) inputZ)
{
    return sanitizeUTF8(inputZ, null, null);
}

/// Sanitize a C string from a library.
/// Returns: Sanitized UTF-8 string. Invalid UTF-8 sequences generate warning messages.
string sanitizeUTF8(const(char*) inputZ, Logger logger, string source)
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
        logger.warningF("got invalid UTF-8 sequence from %s", source);

    return result.data;
}

