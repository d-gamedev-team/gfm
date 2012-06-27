module gfm.common.text;

import std.file;
import std.utf;

string[] readTextFile(string filename)
{
    try
    {
        string data = readText(filename);
        return [data];
    }
    catch(FileException e)
    {
        return null;
    }
    catch(UTFException e)
    {
        return null;
    }    
}