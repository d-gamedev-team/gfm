module gfm.math.box;

import std.traits;
import std.metastrings;

import gfm.math.smallvector, gfm.math.funcs;

// N dimensional half-open interval [a, b[

align(1) struct Box(size_t N, T)
{
    static assert(N > 0);

    public
    {
        alias SmallVector!(N, T) bound_t;

        bound_t a; // not enforced, the box can have negative volume
        bound_t b;

        this(bound_t a_, bound_t b_) pure nothrow
        {
            a = a_;
            b = b_;
        }

        static if (N == 1u)
        {
            this(T ax, T bx) pure nothrow
            {
                a.x = ax;
                b.x = bx;
            }
        }

        static if (N == 2u)
        {
            this(T ax, T ay, T bx, T by) pure nothrow
            {
                a = bound_t(ax, ay);
                b = bound_t(bx, by);
            }
        }

        static if (N == 3u)
        {
            this(T ax, T ay, T az, T bx, T by, T bz) pure nothrow
            {
                a = bound_t(ax, ay, az);
                b = bound_t(bx, by, bz);
            }
        }


        @property
        {
            bound_t size() pure const nothrow
            {
                return b - a;
            }

            bound_t center() pure const nothrow
            {
                return (a + b) / 2;
            }

            static if (N >= 1)
            {
                T width() pure const nothrow @property
                {
                    return b.x - a.x;
                }
            }

            static if (N >= 2)
            {
                T height() pure const nothrow @property
                {
                    return b.y - a.y;
                }
            }

            static if (N >= 3)
            {
                T depth() pure const nothrow @property
                {
                    return b.z - a.z;
                }
            }

            T volume() pure const nothrow
            {
                T res = 1;
                bound_t size = size();
                for(size_t i = 0; i < N; ++i)
                {
                    res *= size[i];
                }
                return res;
            }
        }

        // contains a point
        bool contains(bound_t p) pure const nothrow
        {
            for(size_t i = 0; i < N; ++i)
            {
                if ((p[i] < a[i]) || (p[i] >= b[i]))
                {
                    return false;
                }
            }
            return true;
        }

        // contains another box
        bool contains(Box o) pure const nothrow
        {
            assert(isSorted());
            assert(o.isSorted());

            for(size_t i = 0; i < N; ++i)
            {
                if (o.a[i] >= b[i] || o.b[i] < a[i])
                {
                    return false;
                }
            }
            return true;
        }

        static if (N == 2u)
        {
            Box intersect(ref const(Box) o) pure const nothrow
            {
                assert(isSorted());
                assert(o.isSorted());
                auto xmin = max(a.x, o.a.x);
                auto ymin = max(a.y, o.a.y);
                auto xmax = min(b.x, o.b.x);
                auto ymax = min(b.y, o.b.y);
                return Box(xmin, ymin, xmax, ymax);
            }
        }

        bool isSorted() pure const nothrow
        {
            for(size_t i = 0; i < N; ++i)
            {
                if (a[i] > b[i])
                    return false;
            }
            return true;
        }

        void opAssign(U)(U x) nothrow if (is(typeof(x.isBox)))
        {
            static if(is(U.element_t : T))
            {
                static if(U._size == _size)
                {
                    a = x.a;
                    b = x.b;
                }
                else
                {
                    static assert(false, "no conversion between boxes with different dimensions");
                }
            }
            else
            {
                static assert(false, Format!("no conversion from %s to %s", U.element_t.stringof, element_t.stringof));
            }
        }

        bool opEquals(U)(U other) pure const nothrow if (is(U : Box))
        {
            return (a == other.a) && (b == other.b);
        }
    }

    private
    {
        enum isBox = true;
        enum _size = N;
        alias T element_t;
    }
}

template box2(T)
{
    alias Box!(2u, T) box2;
}

template box3(T)
{
    alias Box!(3u, T) box3;
}

alias box2!int box2i;
alias box3!int box3i;

unittest
{
    box2i a = box2i(1, 2, 3, 4);
    assert(a.width == 2);
    assert(a.height == 2);
    assert(a.volume == 4);
    box2i b = box2i(vec2i(1, 2), vec2i(3, 4));
    assert(a == b);
    box2i c = box2i(0, 0, 1,1);
    assert(c.contains(vec2i(0, 0)));
    assert(!c.contains(vec2i(1, 1)));
    assert(b.contains(b));
}
