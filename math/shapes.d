module gfm.math.shapes;

import std.math, std.traits;
import gfm.math.vector;

// Implement abstract shapes in any number of dimensions like
// - line segment
// - triangle
// - circle/spheres
// - ray

// 2 points
struct Segment(size_t N, T)
{
    public nothrow
    {
        alias Vector!(N, T) point_t;
        point_t a, b;
    }
}

// 3 points
struct Triangle(size_t N, T)
{
    public nothrow
    {
        alias Vector!(N, T) point_t;
        point_t a, b, c;

        static if (N == 2u)
        {
            T area() pure const
            {
                return abs(signedArea());
            }

            T signedArea() pure const
            {
                return ((b.x * a.y - a.x * b.y)
                      + (c.x * b.y - b.x * c.y)
                      + (a.x * c.y - c.x * a.y)) / 2;
            }
        }
    }
}

// a point and a radius
struct Sphere(size_t N, T)
{
    public nothrow
    {
        alias Vector!(N, T) point_t;
        point_t center;
        T radius;

        this(in point_t center_, T radius_) pure nothrow
        {
            center = center_;
            radius = radius_;
        }

        bool contains(in Sphere s) const pure nothrow
        {
            if (s.radius > radius)
                return false;

            T innerRadius = radius - s.radius;
            return squaredDistanceTo(s.center) < innerRadius * innerRadius;
        }

        T squaredDistanceTo(point_t p) pure const nothrow
        {
            return center.squaredDistanceTo(p);
        }

        bool touch(Sphere s) pure const nothrow
        {
            T outerRadius = radius + s.radius;
            return squaredDistanceTo(s.center) < outerRadius * outerRadius;
        }

        static if (isFloatingPoint!T)
        {

            T distanceTo(point_t p) pure const nothrow
            {
                return center.distanceTo(p);
            }

            static if(N == 2u)
            {
                T area() pure const nothrow
                {
                    return PI * (radius * radius);
                }
            }
        }
    }
}

// Ray: describe ray origin + direction
struct Ray(size_t N, T)
{
nothrow:
    public
    {
        alias Vector!(N, T) point_t;
        point_t orig;
        point_t dir;

        point_t progress(T t) pure const
        {
            return orig + dir * t;
        }
    }
}

// Axis-aligned 2D ellipsis.

struct AAEllipse2(T)
{
nothrow:
    public
    {
        T a;
        T b;

        this(T a_, T b_)
        {
            assert(a >= b);
            a = a_;
            b = b_;
        }

        T area() pure const
        {
            return PI * a * b;
        }
    }
}


alias Segment!(2, float) seg2f;
alias Segment!(3, float) seg3f;
alias Segment!(2, double) seg2d;
alias Segment!(3, double) seg3d;

alias Triangle!(2, float) triangle2f;
alias Triangle!(3, float) triangle3f;
alias Triangle!(2, double) triangle2d;
alias Triangle!(3, double) triangle3d;

alias Sphere!(2, float) sphere2f;
alias Sphere!(3, float) sphere3f;
alias Sphere!(2, double) sphere2d;
alias Sphere!(3, double) sphere3d;

alias Ray!(2, float) ray2f;
alias Ray!(3, float) ray3f;
alias Ray!(2, double) ray2d;
alias Ray!(3, double) ray3d;
