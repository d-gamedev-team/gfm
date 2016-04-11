module gfm.image;

public import gfm.image.stb_truetype;

import imageformats;
import ae.utils.graphics.image;
import ae.utils.graphics.color;



/// The one function you probably want to use.
/// Loads an image from a static array.
/// Might throw internally.
/// Throws: $(D ImageIOException) on error.
deprecated("gfm:image package has been merged into package dplug:gui, use it instead")
Image!RGBA loadImage(in void[] imageData)
{
    IFImage ifImage = read_image_from_mem(cast(const(ubyte[])) imageData, 4);
    int width = cast(int)ifImage.w;
    int height = cast(int)ifImage.h;

    Image!RGBA loaded;
    loaded.size(width, height);
    loaded.pixels = cast(RGBA[]) ifImage.pixels; // no pixel copy, GC does the job
    return loaded;
}

/// Loads two different images:
/// - the 1st is the RGB channels
/// - the 2nd is interpreted as greyscale and fetch in the alpha channel of the result.
deprecated("gfm:image package has been merged into package dplug:gui, use it instead")
Image!RGBA loadImageSeparateAlpha(in void[] imageDataRGB, in void[] imageDataAlpha)
{
    IFImage ifImageRGB = read_image_from_mem(cast(const(ubyte[])) imageDataRGB, 3);
    int widthRGB = cast(int)ifImageRGB.w;
    int heightRGB = cast(int)ifImageRGB.h;

    IFImage ifImageA = read_image_from_mem(cast(const(ubyte[])) imageDataAlpha, 1);
    int widthA = cast(int)ifImageA.w;
    int heightA = cast(int)ifImageA.h;

    if ( (widthA != widthRGB) || (heightRGB != heightA) )
    {
        throw new ImageIOException("Image size mismatch");
    }

    int width = widthA;
    int height = heightA;

    Image!RGBA loaded;
    loaded.size(width, height);

    for (int j = 0; j < height; ++j)
    {
        RGB* rgbscan = cast(RGB*)(&ifImageRGB.pixels[3 * (j * width)]);
        ubyte* ascan = &ifImageA.pixels[j * width];
        RGBA[] outscan = loaded.scanline(j);
        for (int i = 0; i < width; ++i)
        {
            RGB rgb = rgbscan[i];
            outscan[i] = RGBA(rgb.r, rgb.g, rgb.b, ascan[i]);
        }
    }
    return loaded;
}


