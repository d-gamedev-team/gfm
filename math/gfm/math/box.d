module gfm.math.box;

import std.math,
       std.traits;

import gfm.math.vector, 
       gfm.math.funcs;

/// N-dimensional half-open interval [a, b[.
align(1) struct Box(T, size_t N)
{
    align(1):
    static assert(N > 0);

    public
    {
        alias Vector!(T, N) bound_t;

        bound_t min; // not enforced, the box can have negative volume
        bound_t max;

        /// Construct a box which extends between 2 points.
        /// Boundaries: min is inside the box, max is just outside.
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
            /// Returns: Dimensions of the box.
            bound_t size() pure const nothrow
            {
                return max - min;
            }

            /// Returns: Center of the box.
            bound_t center() pure const nothrow
            {
                return (min + max) / 2;
            }

            /// Returns: Width of the box, always applicable.
            static if (N >= 1)
            T width() pure const nothrow @property
            {
                return max.x - min.x;
            }

            /// Returns: Height of the box, if applicable.
            static if (N >= 2)
            T height() pure const nothrow @property
            {
                return max.y - min.y;
            }

            /// Returns: Depth of the box, if applicable.
            static if (N >= 3)
            T depth() pure const nothrow @property
            {
                return max.z - min.z;
            }

            /// Returns: Signed volume of the box.
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
                if ( !(point[i] >= min[i] && point[i] < max[i]) )
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

        /// Euclidean squared distance from a point.
        /// See_also: Numerical Recipes Third Edition (2007)
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

        /// Euclidean distance from a point.
        /// See_also: squaredDistance.
        double distance(bound_t point)
        {
            return sqrt(squaredDistance(point));
        }

        /// Assumes sorted boxes.
        /// Returns: Intersection of two boxes.
        Box intersection(Box o) pure const nothrow
        {
            assert(isSorted());
            assert(o.isSorted());
            Box result;
            for (size_t i = 0; i < N; ++i)
            {
                result.min.v[i] = .max(min.v[i], o.min.v[i]);
                result.max.v[i] = .min(max.v[i], o.max.v[i]);
            }
            return result;
        }

        deprecated("Renamed to intersection") alias intersect = intersection;

        /// Assumes sorted boxes.
        /// Returns: true if boxes overlap.
        bool intersects(Box other)
        {
            Box inter = this.intersection(other);
            return inter.isSorted() && inter.volume() != 0;
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

        /// Extends the area of this Box.
        Box grow(T space) pure const nothrow
        {
            return grow(bound_t(space));
        }

        /// Shrink the area of this Box.
        Box shrink(T space) pure const nothrow
        {
            return shrink(bound_t(space));
        }

        /// Returns: true if each dimension of the box is >= 0.
        bool isSorted() pure const nothrow
        {
            for(size_t i = 0; i < N; ++i)
            {
                if (min[i] > max[i])
                    return false;
            }
            return true;
        }

        /// Assign with another box.
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

        /// Returns: true if comparing equal boxes.
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

/// Instanciate to use a 2D box.
template box2(T)
{
    alias Box!(T, 2u) box2;
}

/// Instanciate to use a 3D box.
template box3(T)
{
    alias Box!(T, 3u) box3;
}


alias box2!int box2i; /// 2D box with integer coordinates.
alias box3!int box3i; /// 3D box with integer coordinates.
alias box2!float box2f; /// 2D box with float coordinates.
alias box3!float box3f; /// 3D box with float coordinates.
alias box2!double box2d; /// 2D box with double coordinates.
alias box3!double box3d; /// 3D box with double coordinates.

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
