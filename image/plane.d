module gfm.image.plane;

// A Plane is a triplet of (base address + dimension + stride)
// Simplest image

import std.c.string, std.math;

import gfm.math.vector;
import gfm.image.image;
import gfm.common.alignedbuffer;

struct Plane(T)
{
nothrow:
    public
    {
        alias T element_t;

        this(T* data, vec2i dimension, ptrdiff_t stride)
        {
            _data = data;
            _dimension = dimension;
            _stride = stride;
        }

        this(T* data, vec2i dimension)
        {
            _data = data;
            _dimension = dimension;
            _stride = dimension.x * T.sizeof;
        }

        // create on a provided buffer whose lifetime should be
        this(AlignedBuffer!ubyte buffer, vec2i dimension)
        {
            size_t bytesNeeded = dimension.x * dimension.y * T.sizeof;
            buffer.resize(bytesNeeded);

            this(cast(T*)(buffer.ptr), dimension);
        }

        // return a sub-plane
        Plane subPlane(vec2i position, vec2i dimension)
        {
            assert(contains(position));
            assert(contains(position + dimension - 1));

            return Plane(address(position.x, position.y), dimension, _stride);
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

            int width() const pure
            {
                return _dimension.x;
            }

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

        // copy another plane of same type and dimension
        void copy(Plane source)
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

static assert(isImage!(Plane!int));
static assert(isImage!(Plane!vec4ub));

unittest
{
    {
        int[] b;
        b.length = 10 * 10;
        b[] = 0;
        auto plane = Plane!int(b.ptr, vec2i(10, 5), 20 * int.sizeof);

        fillRect(plane, 1);
        assert(plane.dimension.x == 10);
        assert(plane.dimension.y == 5);

        for (int j = 0; j < 5; ++j)
            for (int i = 0; i < 10; ++i)
                assert(plane.get(i, j) == 1);

        for (int j = 0; j < 5; ++j)
            for (int i = 0; i < 10; ++i)
            {
                assert(b[i + (2 * j) * 10] == 1);
                assert(b[i + (2 * j + 1) * 10] == 0);
            }
    }
}
