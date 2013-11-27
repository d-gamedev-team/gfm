module gfm.math.box;

import std.math,
       std.traits;

import gfm.math.vector, 
       gfm.math.funcs;

/// N-dimensional half-open interval [a, b[
align(1) struct Box(T, size_t N)
{
    static assert(N > 0);

    public
    {
        alias Vector!(T, N) bound_t;

        bound_t min; // not enforced, the box can have negative volume
        bound_t max;

        deprecated("Box.a was renamed to Box.min") alias min a;
        deprecated("Box.b was renamed to Box.max") alias max b;

        /// Construct a box which extends between 2 points.
        /// min is inside the box.
        /// max is just outside.
        this(bound_t min_, bound_t max_) pure nothrow
        {
            min = min_;
            max = max_;
        }

        static if (N == 1u)
        {
            this(T min_, T max_) pure nothrow
            {
                min.x = min_;
                max.x = max_;
            }
        }

        static if (N == 2u)
        {
            this(T min_x, T min_y, T max_x, T max_y) pure nothrow
            {
                min = bound_t(min_x, min_y);
                max = bound_t(max_x, max_y);
            }
        }

        static if (N == 3u)
        {
            this(T min_x, T min_y, T min_z, T max_x, T max_y, T max_z) pure nothrow
            {
                min = bound_t(min_x, min_y, min_z);
                max = bound_t(max_x, max_y, max_z);
            }
        }


        @property
        {
            /// Returns: dimensions of the box.
            bound_t size() pure const nothrow
            {
                return max - min;
            }

            /// Returns: center of the box.
            bound_t center() pure const nothrow
            {
                return (min + max) / 2;
            }

            /// Get the width of the box.
            static if (N >= 1)
            T width() pure const nothrow @property
            {
                return max.x - min.x;
            }

            /// Get the height of the box if applicable.
            static if (N >= 2)
            T height() pure const nothrow @property
            {
                return max.y - min.y;
            }

            /// Get the depth of the box if applicable.
            static if (N >= 3)
            T depth() pure const nothrow @property
            {
                return max.z - min.z;
            }

            T volume() pure const nothrow
            {
                T res = 1;
                bound_t size = size();
                for(size_t i = 0; i < N; ++i)
                    res *= size[i];
                return res;
            }
        }

        /// Returns: true if it contains point.
        bool contains(bound_t point) pure const nothrow
        {
            for(size_t i = 0; i < N; ++i)
                if ((point[i] < min[i]) || (point[i] >= max[i]))
                    return false;

            return true;
        }

        /// Returns: true if it contains box other.
        bool contains(Box other) pure const nothrow
        {
            assert(isSorted());
            assert(other.isSorted());

            for(size_t i = 0; i < N; ++i)
                if (other.min[i] >= max[i] || other.max[i] < min[i])
                    return false;
            return true;
        }

        /// Euclidean squared distance from a point
        /// source: Numerical Recipes Third Edition (2007)
        double squaredDistance(bound_t point) pure const nothrow
        {
            double distanceSquared = 0;
            for (size_t i = 0; i < N; ++i)
            {
                if (point[i] < min[i])
                    distanceSquared += (point[i] - min[i]) ^^ 2;

                if (point[i] > max[i])
                    distanceSquared += (point[i] - max[i]) ^^ 2;
            }
            return distanceSquared;
        }

        // Euclidean distance from a point
        double distance(bound_t point)
        {
            return sqrt(squaredDistance(point));
        }

        static if (N == 2u)
        {
            Box intersect(ref const(Box) o) pure const nothrow
            {
                assert(isSorted());
                assert(o.isSorted());
                auto xmin = .max(min.x, o.min.x);
                auto ymin = .max(min.y, o.min.y);
                auto xmax = .min(max.x, o.max.x);
                auto ymax = .min(max.y, o.max.y);
                return Box(xmin, ymin, xmax, ymax);
            }
        }


        /// Extends the area of this Box.
        Box grow(bound_t space) pure const nothrow
        {
            Box res = this;
            res.min -= space;
            res.max += space;
            return res;
        }

        /// Shrink the area of this Box.
        Box shrink(bound_t space) pure const nothrow
        {
            return grow(-space);
        }

        // shortcut for scalar
        Box grow(T space) pure const nothrow
        {
            return grow(bound_t(space));
        }

        // shortcut for scalar
        Box shrink(T space) pure const nothrow
        {
            return shrink(bound_t(space));
        }

        bool isSorted() pure const nothrow
        {
            for(size_t i = 0; i < N; ++i)
            {
                if (min[i] > max[i])
                    return false;
            }
            return true;
        }

        ref Box opAssign(U)(U x) nothrow if (is(typeof(x.isBox)))
        {
            static if(is(U.element_t : T))
            {
                static if(U._size == _size)
                {
                    min = x.min;
                    max = x.max;
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
            return this;
        }

        bool opEquals(U)(U other) pure const nothrow if (is(U : Box))
        {
            return (min == other.min) && (max == other.max);
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
    alias Box!(T, 2u) box2;
}

template box3(T)
{
    alias Box!(T, 3u) box3;
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
