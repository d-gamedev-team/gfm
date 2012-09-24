module gfm.math.shapes;

import std.math, 
       std.traits;

import gfm.math.vector;

// Implement abstract shapes in any number of dimensions like
// - line segment
// - triangle
// - circle/spheres
// - ray

// 2 points
struct Segment(T, size_t N)
{
    public
    {
        alias Vector!(T, N) point_t;
        point_t a, b;
    }
}

// 3 points
struct Triangle(T, size_t N)
{
    public
    {
        alias Vector!(T, N) point_t;
        point_t a, b, c;

        static if (N == 2u)
        {
            T area() pure const nothrow
            {
                return abs(signedArea());
            }

            T signedArea() pure const nothrow
            {
                return ((b.x * a.y - a.x * b.y)
                      + (c.x * b.y - b.x * c.y)
                      + (a.x * c.y - c.x * a.y)) / 2;
            }
        }
    }
}

// a point and a radius
struct Sphere(T, size_t N)
{
    public nothrow
    {
        alias Vector!(T, N) point_t;
        point_t center;
        T radius;

        this(in point_t center_, T radius_) pure nothrow
        {
            center = center_;
            radius = radius_;
        }

        bool contains(in Sphere s) pure const nothrow
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

        bool intersects(Sphere s) pure const nothrow
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
struct Ray(T, size_t N)
{
nothrow:
    public
    {
        alias Vector!(T, N) point_t;
        point_t orig;
        point_t dir;

        point_t progress(T t) pure const
        {
            return orig + dir * t;
        }

        static if (N == 3u)
        {
            bool intersect(Triangle!(T, 3u) triangle, out T t, out T u, out T v)
            {
                point_t edge1 = triangle.b - triangle.a;
                point_t edge2 = triangle.c - triangle.a;
                point_t pvec = cross(dir, edge2);
                T det = dot(edge1, pvec);
                if (abs(det) < T.epsilon)
                    return false; // no intersection
                T invDet = 1 / det;

                // calculate distance from triangle.a to ray origin
                point_t tvec = orig - triangle.a;

                // calculate U parameter and test bounds 
                u = dot(tvec, pvec) * invDet;
                if (u < 0 || u > 1)
                    return false;

                // prepare to test V parameter
                point_t qvec = cross(tvec, edge1);

                // calculate V parameter and test bounds
                v = dot(dir, qvec) * invDet;
                if (v < 0.0 || u + v > 1.0)
                    return false;

                // calculate t, ray intersects triangle
                t = dot(edge2, qvec) * invDet;
                return true;
            }
        }
    }
}

alias Segment!(float, 2u) seg2f;
alias Segment!(float, 3u) seg3f;
alias Segment!(double, 2u) seg2d;
alias Segment!(double, 3u) seg3d;

alias Triangle!(float, 2u) triangle2f;
alias Triangle!(float, 3u) triangle3f;
alias Triangle!(double, 2u) triangle2d;
alias Triangle!(double, 3u) triangle3d;

alias Sphere!(float, 2u) sphere2f;
alias Sphere!(float, 3u) sphere3f;
alias Sphere!(double, 2u) sphere2d;
alias Sphere!(double, 3u) sphere3d;

alias Ray!(float, 2u) ray2f;
alias Ray!(float, 3u) ray3f;
alias Ray!(double, 2u) ray2d;
alias Ray!(double, 3u) ray3d;