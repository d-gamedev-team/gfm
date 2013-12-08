/**
  This module implements abstract shapes in any number of dimensions like:
  $(UL
  $(LI Line segments.)
  $(LI Triangle.)
  $(LI Circles/spheres.)
  $(LI Rays)
  )
 */
module gfm.math.shapes;

import std.math, 
       std.traits;

import gfm.math.vector;



/// A Segment is 2 points.
/// When considered like a vector, it represents the arrow from a to b.
struct Segment(T, size_t N)
{
    public
    {
        alias Vector!(T, N) point_t;
        point_t a, b;
    }
}

alias Segment!(float, 2u) seg2f;  /// 2D float segment.
alias Segment!(float, 3u) seg3f;  /// 3D float segment.
alias Segment!(double, 2u) seg2d; /// 2D double segment.
alias Segment!(double, 3u) seg3d; /// 3D double segment.

/// A Triangle is 3 points.
/// Bugs: Define normal direction.
struct Triangle(T, size_t N)
{
    public
    {
        alias Vector!(T, N) point_t;
        point_t a, b, c;

        static if (N == 2u)
        {
            /// Returns: Area of a 2D triangle.
            T area() pure const nothrow 
            {
                return abs(signedArea());
            }

            /// Returns: Signed area of a 2D triangle.
            T signedArea() pure const nothrow
            {
                return ((b.x * a.y - a.x * b.y)
                      + (c.x * b.y - b.x * c.y)
                      + (a.x * c.y - c.x * a.y)) / 2;
            }
        }
    }
}

alias Triangle!(float, 2u) triangle2f;  /// 2D float triangle.
alias Triangle!(float, 3u) triangle3f;  /// 3D float triangle.
alias Triangle!(double, 2u) triangle2d; /// 2D double triangle.
alias Triangle!(double, 3u) triangle3d; /// 3D double triangle.

/// A Sphere is a point + a radius.
struct Sphere(T, size_t N)
{
    public nothrow
    {
        alias Vector!(T, N) point_t;
        point_t center;
        T radius;

        /// Creates a sphere from a point and a radius.
        this(in point_t center_, T radius_) pure nothrow
        {
            center = center_;
            radius = radius_;
        }

        /// Sphere contains point test.
        /// Returns: true if the point is inside the sphere.
        bool contains(in Sphere s) pure const nothrow
        {
            if (s.radius > radius)
                return false;

            T innerRadius = radius - s.radius;
            return squaredDistanceTo(s.center) < innerRadius * innerRadius;
        }

        /// Sphere vs point Euclidean distance squared.
        T squaredDistanceTo(point_t p) pure const nothrow
        {
            return center.squaredDistanceTo(p);
        }

        /// Sphere vs sphere intersection.
        /// Returns: true if the spheres intersect.
        bool intersects(Sphere s) pure const nothrow
        {
            T outerRadius = radius + s.radius;
            return squaredDistanceTo(s.center) < outerRadius * outerRadius;
        }

        static if (isFloatingPoint!T)
        {
            /// Sphere vs point Euclidean distance.
            T distanceTo(point_t p) pure const nothrow
            {
                return center.distanceTo(p);
            }

            static if(N == 2u)
            {
                /// Returns: Circle area.
                T area() pure const nothrow
                {
                    return PI * (radius * radius);
                }
            }
        }
    }
}

alias Sphere!(float, 2u) sphere2f;  /// 2D float sphere (ie. a circle).
alias Sphere!(float, 3u) sphere3f;  /// 3D float sphere.
alias Sphere!(double, 2u) sphere2d; /// 2D double sphere (ie. a circle).
alias Sphere!(double, 3u) sphere3d; /// 3D double sphere (ie. a circle).


/// A Ray ir a point + a direction.
struct Ray(T, size_t N)
{
nothrow:
    public
    {
        alias Vector!(T, N) point_t;
        point_t orig;
        point_t dir;

        /// Returns: A point further along the ray direction.
        point_t progress(T t) pure const
        {
            return orig + dir * t;
        }

        static if (N == 3u)
        {
            /// Ray vs triangle intersection.
            /// Bugs: Verify what triangle axis is reffered to.
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

alias Ray!(float, 2u) ray2f;  /// 2D float ray.
alias Ray!(float, 3u) ray3f;  /// 3D float ray.
alias Ray!(double, 2u) ray2d; /// 2D double ray.
alias Ray!(double, 3u) ray3d; /// 3D double ray.
