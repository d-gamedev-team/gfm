module gfm.core.queue;

import std.range;

import core.sync.mutex,
       core.sync.semaphore;

import gfm.core.memory;

// what to do when capacity is exceeded?
private enum OverflowPolicy
{
    GROW,
    CRASH,
    DROP
}

/**

    Doubly-indexed queue, can be used as a FIFO or stack.

    Bugs:
        Doesn't call struct destructors, don't scan memory.
        You should probably only put POD types in them.
 */
deprecated("Use emsi_containers instead") final class QueueImpl(T, OverflowPolicy overflowPolicy)
{
    public
    {
        /// Create a QueueImpl with specified initial capacity.
        this(size_t initialCapacity) nothrow
        {
            _data.length = initialCapacity;
            clear();
        }

        /// Returns: true if the queue is full.
        @property bool isFull() pure const nothrow
        {
            return _count == capacity;
        }

        /// Returns: capacity of the queue.
        @property size_t capacity() pure const nothrow
        {
            return _data.length;
        }

        /// Adds an item on the back of the queue.
        void pushBack(T x) nothrow
        {
            checkOverflow!popFront();
           _data[(_first + _count) % _data.length] = x;
            ++_count;
        }

        /// Adds an item on the front of the queue.
        void pushFront(T x) nothrow
        {
            checkOverflow!popBack();
            ++_count;
            _first = (_first - 1 + _data.length) % _data.length;
            _data[_first] = x;
        }

        /// Removes an item from the front of the queue.
        /// Returns: the removed item.
        T popFront() nothrow
        {
            crashIfEmpty();
            T res = _data[_first];
            _first = (_first + 1) % _data.length;
            --_count;
            return res;
        }

        /// Removes an item from the back of the queue.
        /// Returns: the removed item.
        T popBack() nothrow
        {
            crashIfEmpty();
            --_count;
            return _data[(_first + _count) % _data.length];
        }

        /// Removes all items from the queue.
        void clear() nothrow
        {
            _first = 0;
            _count = 0;
        }

        /// Returns: number of items in the queue.
        size_t length() pure const nothrow
        {
            return _count;
        }

        /// Returns: item at the front of the queue.
        T front() pure
        {
            crashIfEmpty();
            return _data[_first];
        }

        /// Returns: item on the back of the queue.
        T back() pure
        {
            crashIfEmpty();
            return _data[(_first + _count + _data.length - 1) % _data.length];
        }

        /// Returns: item index from the queue.
        T opIndex(size_t index)
        {
            // crash if index out-of-bounds (not recoverable)
            if (index > _count)
                assert(0);

            return _data[(_first + index) % _data.length];
        }

        /// Returns: random-access range over the whole queue.
        Range opSlice() nothrow
        {
            return Range(this);
        }

        /// Returns: random-access range over a queue sub-range.
        Range opSlice(size_t i, size_t j) nothrow
        {
            // verify that all elements are in bound
            if (i != j && i >= _count)
                assert(false);

            if (j > _count)
                assert(false);

            if (j < i)
                assert(false);

            return Range(this);
        }

        // range type, random access
        static struct Range
        {
        nothrow:
            public
            {
                this(QueueImpl queue) pure
                {
                    this(queue, 0, queue._count);
                    _first = queue._first;
                    _count = queue._count;
                }

                this(QueueImpl queue, size_t index, size_t count) pure
                {
                    _index = index;
                    _data = queue._data;
                    _first = (queue._first + index) % _data.length;
                    _count = _count;
                }

                @property bool empty() pure const
                {
                    return _index >= _count;
                }

                void popFront()
                {
                    _index++;
                }

                @property T front() pure
                {
                    return _data[(_first + _index) % _data.length];
                }

                void popBack()
                {
                    _count--;
                }

                @property T back() pure
                {
                    return _data[(_first + _count - 1) % _data.length];
                }

                @property Range save()
                {
                    return this;
                }

                T opIndex(size_t i)
                {
                    // crash if index out-of-bounds of the range (not recoverable)
                    if (i > _count)
                        assert(0);

                    return _data[(_first + _index + i) % _data.length];
                }

                @property size_t length() pure
                {
                    return _count;
                }

                alias length opDollar;
            }

            private
            {
                size_t _index;
                T[] _data;
                size_t _first;
                size_t _count;
            }
        }
    }

    private
    {
        void crashIfEmpty()
        {
            // popping if empty is not a recoverable error
            if (_count == 0)
                assert(false);
        }

        // element lie from _first to _first + _count - 1 index, modulo the allocated size
        T[] _data;
        size_t _first;
        size_t _count;

        void checkOverflow(alias popMethod)() nothrow
        {
            if (isFull())
            {
                static if (overflowPolicy == OverflowPolicy.GROW)
                    extend();

                static if (overflowPolicy == OverflowPolicy.CRASH)
                    assert(false); // not recoverable to overflow such a queue

                static if (overflowPolicy == OverflowPolicy.DROP)
                    popMethod();
            }
        }

        void extend() nothrow
        {
            size_t newCapacity = capacity * 2;
            if (newCapacity < 8)
                newCapacity = 8;

            assert(newCapacity >= _count + 1);

            T[] newData = new T[newCapacity];

            auto r = this[];
            size_t i = 0;
            while (!r.empty())
            {
                newData[i] = r.front();
                r.popFront();
                ++i;
            }
            _data = newData;
            _first = 0;
        }
    }
}

static assert (isRandomAccessRange!(Queue!int.Range));


/**

A queue that can only grow.


See_also: $(LINK2 #QueueImpl, QueueImpl)

*/
template Queue(T)
{
    alias QueueImpl!(T, OverflowPolicy.GROW) Queue;
}

/**

A fixed-sized queue that will crash on overflow.

See_also: $(LINK2 #QueueImpl, QueueImpl)


*/
template FixedSizeQueue(T)
{
    alias QueueImpl!(T, OverflowPolicy.CRASH) FixedSizeQueue;
}

/**

Ring buffer, it drops if its capacity is exceeded.

See_also: $(LINK2 #QueueImpl, QueueImpl)

*/
template RingBuffer(T)
{
    alias QueueImpl!(T, OverflowPolicy.DROP) RingBuffer;
}

