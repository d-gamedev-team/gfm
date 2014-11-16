module gfm.core.text;

import std.file,
       std.utf,
       std.conv,
       std.encoding,
       std.array,
       std.c.string;

/// Sanitize a C string from a library.
/// Returns: Sanitized UTF-8 string. Invalid UTF-8 sequences are replaced by question marks.
string sanitizeUTF8(const(char*) inputZ)
{
    assert(inputZ != null);
    size_t inputLength = strlen(inputZ);

    auto result = appender!string();
    result.reserve(inputLength);

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
            ++i; 
        }    
        char[4] dst;
        auto len = std.utf.encode(dst, ch);
        result.put(dst[0 .. len]);
    }

    return result.data;
}

