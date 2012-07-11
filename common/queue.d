module gfm.common.queue;

import std.range;

// doubly-indexed queue, canbe used as a FIFO or stack
final class Queue(T)
{
nothrow:
    public
    {
        this(size_t capacity)
        {
            _data.length = capacity;
            clear();
        }

        @property size_t capacity() const
        {
            return _data.length;
        }

        void pushBack(T x)
        {
            assert(_count < capacity);
            _data[(_first + _count) % _data.length] = x;
            ++_count;
        }

        void pushFront(T x)
        {
            assert(_count < capacity);
            ++_count;
            _first = (_first - 1 + _data.length) % _data.length;
            _data[_first] = x;
        }

        T popFront()
        {
            assert(_count > 0);
            T res = _data[_first];
            _first = (_first + 1) % _data.length;
            --_count;
            return res;
        }

        T popBack()
        {
            assert(_count > 0);
            --_count;
            return _data[(_first + _count) % _data.length];
        }

        void clear()
        {
            _first = 0;
            _count = 0;
        }

        size_t length()
        {
            return _count;
        }

        // range type
        // Todo: make it random access
        static struct Range
        {
        nothrow:
            public
            {
                this(Queue queue) pure
                {
                    _index = 0;
                    _data = queue._data;
                    _first = queue._first;
                    _count = queue._count;
                }

                @property bool empty() pure const
                {
                    return _index >= _count;
                }

                @property void popFront()
                {
                    _index++;
                }

                @property T front() pure
                {
                    return _data[(_first + _index) % _data.length];
                }

                // implementing save to be a forward range
                @property Range save()
                {
                    return this;
                }
            }

            private
            {
                size_t _index;
                T[] _data;
                size_t _first;
                size_t _count;
            }
        }

        // get forward range
        Range range()
        {
            return Range(this);
        }
    }

    private
    {
        T[] _data;
        size_t _first;
        size_t _count; // number of elem in FIFO
    }
}

static assert (isInputRange!(Queue!int.Range));
static assert (isForwardRange!(Queue!int.Range));

unittest
{
    // fifo
    {
        int N = 7;
        auto fifo = new Queue!int(N);
        foreach(n; 0..N)
            fifo.pushBack(n);

        foreach(n; 0..N)
        {
            assert(fifo.popFront() == n);
        }
    }

    // stack
    {
        int N = 7;
        auto fifo = new Queue!int(N);
        foreach(n; 0..N)
            fifo.pushBack(n);

        foreach(n; 0..N)
            assert(fifo.popBack() == N - 1 - n);
    }
}
