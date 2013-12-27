/**
  This module introduces some Image implementations.
*/
module gfm.image.bitmap;

import std.c.string, 
       std.math;

import gfm.core.alignedbuffer,
       gfm.core.memory,
       gfm.math.vector;

import gfm.image.image;

/**
    Simple planar image implementing the Image concept.
    A Bitmap is mostly a triplet of (base address + dimension + stride).
    Data can be owned or not.
 */
struct Bitmap(T)
{
nothrow:
    public
    {
        alias T element_t;

        /// Creates a Bitmap with owned memory.
        this(vec2i dimension) nothrow
        {
            _data = alignedMalloc(dimension.x * dimension.y * T.sizeof, 64);
            _dimension = dimension;
            _stride = dimension.x * T.sizeof;
            _owned = true;
        }

        /// Creates a Bitmap from borrowed memory.
        this(T* data, vec2i dimension, ptrdiff_t stride) nothrow
        {
            _data = data;
            _dimension = dimension;
            _stride = stride;
            _owned = false;
        }

        /// Creates a Bitmap from borrowed contiguous memory.
        this(T* data, vec2i dimension) nothrow
        {
            this(data, dimension, dimension.x * T.sizeof);
        }

        /// Creates with a buffer whose lifetime should be greater than this.
        this(AlignedBuffer!ubyte buffer, vec2i dimension) nothrow
        {
            size_t bytesNeeded = dimension.x * dimension.y * T.sizeof;
            buffer.resize(bytesNeeded);

            this(cast(T*)(buffer.ptr), dimension);
        }

        ~this()
        {
            if (_owned)
                alignedFree(_data);
        }

        // postblit needed to duplicate owned data
        this(this) nothrow
        {
            if (_owned)
            {
                size_t sizeInBytes = _dimension.x * _dimension.y * T.sizeof;
                void* oldData = _data;
                _data = alignedMalloc(sizeInBytes, 64);
                memcpy(_data, oldData, sizeInBytes);
            }
        }

        auto opAssign(Bitmap other) nothrow
        {
            _data = other._data;
            _dimension = other._dimension;
            _stride = other._stride;
            _owned = other._owned;
            return this;
        }

        /// Returns: A sub-bitmap from a Bitmap.
        Bitmap subImage(vec2i position, vec2i dimension)
        {
            assert(contains(position));
            assert(contains(position + dimension - 1));

            return Bitmap(address(position.x, position.y), dimension, _stride);
        }

        @property
        {
            T* ptr()
            {
                return cast(T*) _data;
            }

            const(T)* ptr() const
            {
                return cast(T*) _data;
            }

            vec2i dimension() const pure
            {
                return _dimension;
            }

            /// Returns: Width of image in pixels.
            int width() const pure
            {
                return _dimension.x;
            }

            /// Returns: Height of image in pixels.
            int height() const pure
            {
                return _dimension.y;
            }

        }

        T get(int i, int j) const pure
        {
            return *(address(i, j));
        }

        void set(int i, int j, T e)
        {
            *(address(i, j)) = e;
        }

        bool isDense() const pure
        {
            return (_stride == _dimension.x * T.sizeof);
        }

        bool contains(vec2i point)
        {
            return (cast(uint)(point.x) < cast(uint)(_dimension.x))
                && (cast(uint)(point.y) < cast(uint)(_dimension.y));
        }

        /// copy another Bitmap of same type and dimension
        void copy(Bitmap source)
        {
            assert(dimension == source.dimension);
            if (isDense() && source.isDense())
            {
                size_t bytes = dimension.x * dimension.y * T.sizeof;
                memcpy(_data, source._data, bytes);
            }
            else if(_stride == source._stride)
            {
                size_t bytes = _stride * dimension.y;
                memcpy(_data, source._data, bytes);
            }
            else
            {
                void* dest = _data;
                void* src = source._data;
                size_t lineSize = abs(_stride);

                for (size_t j = 0; j < dimension.y; ++j)
                {
                    memcpy(dest, src, lineSize);
                    dest += _stride;
                    src += source._stride;
                }
            }
        }
    }

    private
    {
        vec2i _dimension;
        void* _data;
        ptrdiff_t _stride;       // in bytes
        bool _owned;

        T* address(int i, int j) pure
        {
            return cast(T*)(_data + _stride * j + T.sizeof * i);
        }

        const(T)* address(int i, int j) const pure // :| where is inout(this)?
        {
            return cast(T*)(_data + _stride * j + T.sizeof * i);
        }
    }
}

static assert(isImage!(Bitmap!int));
static assert(isImage!(Bitmap!vec4ub));

unittest
{
    {
        int[] b;
        b.length = 10 * 10;
        b[] = 0;
        auto bitmap = Bitmap!int(b.ptr, vec2i(10, 5), 20 * int.sizeof);

        fillImage(bitmap, 1);
        assert(bitmap.dimension.x == 10);
        assert(bitmap.dimension.y == 5);

        for (int j = 0; j < 5; ++j)
            for (int i = 0; i < 10; ++i)
                assert(bitmap.get(i, j) == 1);

        for (int j = 0; j < 5; ++j)
            for (int i = 0; i < 10; ++i)
            {
                assert(b[i + (2 * j) * 10] == 1);
                assert(b[i + (2 * j + 1) * 10] == 0);
            }
    }
}


/**
  A TiledBitmap is like a Bitmap but pixels are organized in tiles.
 */
struct TiledBitmap(T, size_t tileWidth, size_t tileHeight)
{    
    static assert(tileWidth >= 1 && isPowerOf2(tileWidth));
    static assert(tileHeight >= 1 && isPowerOf2(tileHeight));

nothrow:
    public
    {
        enum tileSize = tileWidth * tileHeight;
        alias T element_t;
        alias T[tileSize] tile_t;

        Bitmap!tile_t tiles; // a Bitmap of tiles

        /// Create with owned memory, dimension is given in tiles
        this(vec2i dimension)
        {
            tiles = Bitmap!tile_t(dimension);
        }

        T get(int i, int j) const pure
        {
            return *(address(i, j));
        }

        void set(int i, int j, T e)
        {
            *(address(i, j)) = e;
        }

        @property
        {
            T* ptr()
            {
                return tiles.ptr;
            }

            const(T)* ptr() const
            {
                return tiles.ptr;
            }

            vec2i dimension() const pure
            {
                return tiles.dimension * vec2i(tileWidth, tileHeight);
            }

            int width() const pure
            {
                return tiles.width * tileWidth;
            }

            int height() const pure
            {
                return tiles.height * tileHeight;
            }
        }
    }

    private
    {
        enum X_MASK = tileWidth - 1,
             Y_MASK = tileHeight - 1,
             X_SHIFT = ilog2(tileWidth),
             Y_SHIFT = ilog2(tileHeight);
        
        T* address(int i, int j) pure
        {
            tile_t* tile = tiles.address(i >> X_SHIFT, j >> Y_SHIFT);
            size_t tileIndex = tileWeight * (i & X_MASK) + (j & Y_MASK);
            return tile.ptr + tileIndex;
        }

        const(T)* address(int i, int j) const pure
        {
            tile_t* tile = tiles.address(i >> X_SHIFT, j >> Y_SHIFT);
            size_t tileIndex = tileWeight * (i & X_MASK) + (j & Y_MASK);
            return tile.ptr + tileIndex;
        }
    }
}
