module gfm.common.text;

import std.file,
       std.utf,
       std.conv,
       std.encoding,
       std.c.string;

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

/**
 * Read a C string and return a sanitized utf-8 string.
 * Used when interfacing with C libraries which may output anything.
 */
string sanitizeUTF8(const(char*) inputZ)
{
    assert(inputZ != null);
    size_t len = strlen(inputZ);
    immutable(ubyte)[] input = (cast(immutable(ubyte*))inputZ)[0..len];
    const(ubyte)[] res = (new EncodingSchemeUtf8).sanitize(input);
    return to!string(cast(const(char)*)res);
}