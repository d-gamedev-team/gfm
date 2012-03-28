module gfm.image.image;

import gfm.math.smallvector;

// An image is a concept

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

void fillRect(I, P)(I img, int x, int y, int width, int height, P e) if (isImage!I && is(P : I.element_t))
{
    for (int j = 0; j < height; ++j)
        for (int i = 0; i < width; ++i)
            img.set(x + i, y + j, e);
}


void fillRect(I, P)(I img, P e) if (isImage!I && is(P : I.element_t))
{
    immutable int width = img.dimension.x;
    immutable int height = img.dimension.y;
    for (int j = 0; j < height; ++j)
        for (int i = 0; i < width; ++i)
            img.set(i, j, e);
}

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
