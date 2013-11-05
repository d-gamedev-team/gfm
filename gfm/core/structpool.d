module gfm.core.structpool;


// Manage memory allocation for same-sized non-contiguous structs
// non-growable
// for POD types only
// TODO: this class sucks. Will be removed once std.allocator is ready.
deprecated class StructPool(T)
{
    public
    {
        this(size_t capacity)
        {
            _slots.length = capacity;

            if (capacity > 0)
            {
                for(size_t i = 0; i < capacity - 1; ++i)
                {
                    _slots[i]._nextFree = &_slots[i + 1];
                }
                _slots[capacity - 1]._nextFree = null;
                _firstFree = &_slots[0];
            }
            else
            {
                _firstFree = null;
            }

            _count = 0;
        }

        T* alloc()
        {
            return cast(T*)allocSlot();
        }

        void release(T* t)
        {
            releaseSlot(cast(Slot*)t);
        }

        pure @property const
        {
            bool empty()
            {
                return (_count == 0);
            }

            bool full()
            {
                return _firstFree == null;
            }

            size_t capacity()
            {
                return _slots.length;
            }

            size_t count()
            {
                return _count;
            }

            float usage()
            {
                return count() / cast(float)(capacity());
            }
        }
    }

    private
    {
        Slot* _firstFree;

        align(1) struct Slot
        {
            union
            {
                T _element;
                Slot* _nextFree;
            }
        }
        enum cellSize = T.sizeof > size_t.sizeof ? T.sizeof : size_t.sizeof;
        static assert(Slot.sizeof == cellSize);

        Slot[] _slots; // data.length is capacity

        size_t _count;

        // return struct storage
        Slot* allocSlot()
        {
            assert(!full(), "StructPool is full"); // TODO: implement growable
            if (full())
            {
                return null;
            }

            Slot* res = _firstFree;
            _firstFree = _firstFree._nextFree;

            ++_count;
            return res;
        }

        // release struct storage
        void releaseSlot(Slot* t)
        {
            assert(isSlot(t));
            --_count;
            t._nextFree = _firstFree;
            _firstFree = t;
        }

        // return true if t points to a valid slot
        bool isSlot(Slot* t)
        {
            size_t ti = cast(size_t)t;
            size_t si = cast(size_t)(_slots.ptr);
            size_t di = ti - si;
            if (di >= Slot.sizeof * _slots.length) // out of bounds
            {
                return false;
            }

            if ((di % Slot.sizeof) != 0) // not on a slot
            {
                return false;
            }

            return true;
        }

        bool isFree(Slot* t)
        {
            Slot* f = _firstFree;
            while(f !is null)
            {
                if (f is t)
                {
                    return true;
                }
                f = f._nextFree;
            }
            return false;
        }

        bool isAllocated(Slot* t)
        {
            return isSlot(t) && (!isFree(t));
        }
    }
}

