/**
  This module defines the notion of an Image.   
  An Image is simply defined as a 2D array of elements, with
  methods to set/get those elements.

  The Image concept might be the basis of a generic software renderer.
 */
module gfm.image.image;

import gfm.math.vector;

// An image is a concept


/**
 * Test if I is an Image.
 *
 * An image has the following features:
 * $(UL
 * $(LI defines element_t as the type of elements (eg. pixels).)
 * $(LI has a dimension of type vec2i.)
 * $(LI has getter/setter for individual elements.)
 * )
 */
template isImage(I)
{
    enum bool isImage = is(typeof(
    {
        I i;                            // can be defined
        const I ci;
        I.element_t e;                  // defined the type element_t
        vec2i dim = ci.dimension;       // has dimension
        I.element_t f = ci.get(0, 0);   // can get element
        i.set(0, 0, f);                 // can set element
    }()));
}

/// Returns: true if an image contains the given point.
deprecated("Use ae.utils.graphics instead") 
bool contains(I)(I img, int x, int y) if (isImage!I)
{
    return cast(uint)x < img.dimension.x && cast(uint)y < img.dimension.y;
}

/// EdgeMode defines how images are sampled beyond their boundaries.
deprecated("Use ae.utils.graphics instead")
enum EdgeMode
{
    BLACK,  /// Return black.
    CLAMP,  /// Clamp to edge.
    REPEAT, /// Repeat from the other side of the image.
    CRASH   /// Crash.
}


/// Draws a single pixel.
deprecated("Use ae.utils.graphics instead")
void drawPixel(I, P)(I img, int x, int y, P p) if (isImage!I && is(P : I.element_t))
{
    if (!img.contains(x, y))
        return;
    img.set(x, y, p);
}

/// Returns: pixel of an Image at position (x, y). 
/// At boundaries, what happens depends on em.
deprecated("Use ae.utils.graphics instead")
I.element_t getPixel(I)(I img, int x, int y, EdgeMode em)
{
    if (!img.contains(x, y))
    {
        final switch(em)
        {
            case EdgeMode.BLACK:
                return I.element_t.init;

            case EdgeMode.CLAMP:
            {
                if (x < 0) x = 0;
                if (y < 0) y = 0;
                if (x >= img.dimension.x) x = img.dimension.x - 1;
                if (y >= img.dimension.y) y = img.dimension.y - 1;
                break;
            }

            case EdgeMode.REPEAT:
            {
                x = moduloWrap!int(x, img.dimension.x);
                y = moduloWrap!int(y, img.dimension.y);
                break;
            }

            case EdgeMode.CRASH: 
                assert(false);
        }
    }
    
    return img.get(x, y);
}

/// Draws a rectangle outline in an Image.
deprecated("Use ae.utils.graphics instead")
void drawRect(I, P)(I img, int x, int y, int width, int height, P e) if (isImage!I && is(P : I.element_t))
{
    drawHorizontalLine(img, x, x + width, y, e);
    drawHorizontalLine(img, x, x + width, y + height - 1, e);
    drawVerticalLine(img, x, y, y + height, e);
    drawVerticalLine(img, x + width - 1, y, y + height, e);
}

/// Fills an uniform rectangle area in an Image.
deprecated("Use ae.utils.graphics instead")
void fillRect(I, P)(I img, int x, int y, int width, int height, P e) if (isImage!I && is(P : I.element_t))
{
    for (int j = 0; j < height; ++j)
        for (int i = 0; i < width; ++i)
            img.set(x + i, y + j, e);
}

/// Fills a whole image with a single element value.
deprecated("Use ae.utils.graphics instead")
void fillImage(I, P)(I img, P e) if (isImage!I && is(P : I.element_t))
{
    immutable int width = img.dimension.x;
    immutable int height = img.dimension.y;
    for (int j = 0; j < height; ++j)
        for (int i = 0; i < width; ++i)
            img.set(i, j, e);
}

/// Performs an image blit from src to dest.
deprecated("Use ae.utils.graphics instead")
void copyRect(I)(I dest, I src) if (isImage!I)
{
    // check same size
    assert(dest.dimension == src.dimension);

    immutable int width = dest.dimension.x;
    immutable int height = dest.dimension.y;
    for (int j = 0; j < height; ++j)
        for (int i = 0; i < width; ++i)
        {
            auto p = src.get(i, j);
            dest.set(i, j, p);
        }
}

/// Draws an horizontal line on an Image.
deprecated("Use ae.utils.graphics instead")
void drawHorizontalLine(I, P)(I img, int x1, int x2, int y, P p) if (isImage!I && is(P : I.element_t))
{
    for (int x = x1; x < x2; ++x)
        img.drawPixel(x, y, p);
}

/// Draws a vertical line on an Image.
deprecated("Use ae.utils.graphics instead")
void drawVerticalLine(I, P)(I img, int x, int y1, int y2, P p) if (isImage!I && is(P : I.element_t))
{
    for (int y = y1; y < y2; ++y)
        img.drawPixel(x, y, p);
}
