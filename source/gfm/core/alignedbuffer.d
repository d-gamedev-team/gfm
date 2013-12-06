module gfm.core.alignedbuffer;

import std.c.string;
import gfm.core.memory;

/// Growable array, points to a memory aligned location.
/// Bugs: make this class disappear when std.allocator is out.
final class AlignedBuffer(T)
{
    public
    {
        /// Creates an empty aligned buffer.
        this() nothrow
        {
            _size = 0;
            _allocated = 0;
            _data = null;
            _alignment = 64;
        }

        /// Creates an aligned buffer with given size.
        this(size_t initialSize) nothrow
        {
            this();
            resize(initialSize);
        }

        /// Creates an aligned buffer by copy.
        this(AlignedBuffer other)
        {
            this();
            resize(other.length());
            memcpy(_data, other._data, _size * T.sizeof);
        }

        ~this()
        {
            close();
        }

        deprecated("release was renamed to close") alias close release;
        void close()
        {
            if (_data !is null)
            {
                alignedFree(_data);
                _data = null;
                _allocated = 0;
            }
        }

        size_t length() pure const nothrow
        {
            return _size;
        }

        void resize(size_t askedSize) nothrow
        {
            // grow only
            if (_allocated < askedSize)
            {
                _data = cast(T*)(alignedRealloc(_data, askedSize * T.sizeof, _alignment));
                _allocated = askedSize;
            }
            _size = askedSize;
        }

        void pushBack(T x) nothrow
        {
            size_t i = _size;
            resize(_size + 1);
            _data[i] = x;
        }

        // push back another buffer
        void pushBack(AlignedBuffer other) nothrow
        {
            size_t oldSize = _size;
            resize(_size + other._size);
            memcpy(_data + oldSize, other._data, T.sizeof * other._size);
        }

        @property T* ptr() nothrow
        {
            return _data;
        }

        T opIndex(size_t i) pure nothrow
        {
            return _data[i];
        }

        T opIndexAssign(T x, size_t i) nothrow
        {
            return _data[i] = x;
        }

        void clear() nothrow
        {
            _size = 0;
        }

        void fill(T x)
        {
            for (size_t i = 0; i < _size; ++i)
            {
                _data[i] = x;                
            }
        }
    }

    private
    {
        size_t _size;
        T* _data;
        size_t _allocated;
        size_t _alignment;
    }
}

unittest
{
    auto buf = new AlignedBuffer!int;
    enum N = 10;
    buf.resize(N);
    foreach(i ; 0..N)
        buf[i] = i;

    foreach(i ; 0..N)
        assert(buf[i] == i);
}
