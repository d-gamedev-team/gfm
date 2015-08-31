import std.stdio,
       std.file;

import ae.utils.graphics;

import gfm.image;

// Loads an image, make it greyscale and saves it to PNG.

void main(string[] args)
{
    if (args.length != 2)
    {
        writefln("Usage: image_io <source>");
        writefln("       Loads an image, make it greyscale and saves it to PNG.");
        return;
    }

    string source = args[1];

    static RGBA toGrey(RGBA c)
    {
        ubyte grey = (c.r + c.g + c.b) / 3;
        return RGBA(grey, grey, grey);
    }

    auto processed = loadImage(std.file.read(source)).colorMap!toGrey.toPNG();
    std.file.write("output.png", processed);
}
