module gfm.image.yv12image;

// struct that describe all three planes of an YV12 image

import std.stdio;

import gfm.math.vector;
import gfm.common.alignedbuffer;
import gfm.image.plane;

struct YV12Image
{
nothrow:
    public
    {
        Plane!ubyte Y;
        Plane!ubyte V;
        Plane!ubyte U;

        this(ubyte* pixels[3], vec2i dimension, ptrdiff_t strides[3])
        {
            Y = Plane!ubyte(pixels[0], dimension, strides[0]);
            V = Plane!ubyte(pixels[1], dimension >> 1, strides[1]);
            U = Plane!ubyte(pixels[2], dimension >> 1, strides[2]);
        }

        // create on a provided buffer whose lifetime should be
        // managed by caller
        this(AlignedBuffer!ubyte buffer, vec2i dimension)
        {
            // TODO: create aligned?
            size_t Ysize = dimension.x * dimension.y;
            size_t UVsize = (dimension.x / 2) * (dimension.y / 2);
            size_t bytesNeeded = Ysize + UVsize * 2;
            buffer.resize(bytesNeeded);

            Y = Plane!ubyte(buffer.ptr, dimension);
            V = Plane!ubyte(buffer.ptr + Ysize, dimension >> 1);
            U = Plane!ubyte(buffer.ptr + (Ysize + UVsize), dimension >> 1);
        }

        // copy another image of same dimension
        void copy(YV12Image src)
        {
            Y.copy(src.Y);
            V.copy(src.V);
            U.copy(src.U);
        }
    }
}

unittest
{
    auto buf = new AlignedBuffer!ubyte;
    auto yv12Image = YV12Image(buf, vec2i(25, 25));
}
