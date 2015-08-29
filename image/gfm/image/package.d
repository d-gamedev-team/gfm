module gfm.image;

public import gfm.image.stb_truetype;

import imageformats;
import ae.utils.graphics.image;
import ae.utils.graphics.color;

/// The one function you probably want to use.
/// Loads an image from a static array.
/// Might throw internally.
/// Throws: $(D ImageIOException) on error.
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

deprecated("Use loadImage instead") alias stbiLoadImageAE = loadImage;

