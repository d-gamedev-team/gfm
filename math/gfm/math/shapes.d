/**
  This module implements some abstract geometric shapes:
  $(UL
  $(LI Line segments.)
  $(LI Triangle.)
  $(LI Circles/spheres.)
  $(LI Rays)
  $(LI Planes)
  $(LI Frustum)
  )
 */
module gfm.math.shapes;

import std.math,
       std.traits;

import gfm.math.vector,
       gfm.math.box;

/// A Segment is 2 points.
/// When considered like a vector, it represents the arrow from a to b.
struct Segment(T, int N)
{
    public
    {
        alias Vector!(T, N) point_t;
        point_t a, b;

        static if (N == 3 && isFloatingPoint!T)
        {
            /// Segment vs plane intersection.
            /// See_also: "Geometry for Computer Graphics: Formulae, Examples
            ///     and Proofs", Vince (2005), p. 62
            /// Returns: $(D true) if the segment crosses the plane exactly
            ///     once, or $(D false) if the segment is parallel to or does
            ///     not reach the plane
            /// Params:
            ///     plane = The plane to intersect.
            ///     intersection = Point of intersection.
            ///     progress = Set to the point's progress between endpoints
            ///                $(D a) at 0.0 and $(D b) at 1.0, or T.infinity
            ///                if parallel to the plane
            @nogc bool intersect(Plane!T plane, out point_t intersection, out T progress) pure const nothrow
            {
                // direction vector from a to b
                point_t dir = b-a;

                // dot product will be 0 if angle to plane is 0
                T dp = dot(plane.n, dir);
                if (abs(dp) < T.epsilon)
                {
                    progress = T.infinity;
                    return false; // parallel to plane
                }

                // relative distance along segment where intersection happens
                progress = -(dot(plane.n, a) - plane.d) / dp;

                intersection = progress*dir + a;
                return progress >= 0 && progress <= 1;
            }
        }
    }
}

alias Segment!(float, 2) seg2f;  /// 2D float segment.
alias Segment!(float, 3) seg3f;  /// 3D float segment.
alias Segment!(double, 2) seg2d; /// 2D double segment.
alias Segment!(double, 3) seg3d; /// 3D double segment.
alias Segment!(int, 2) seg2i;    /// 2D integer segment.
alias Segment!(int, 3) seg3i;    /// 3D integer segment.

/// A Triangle is 3 points.
struct Triangle(T, int N)
{
    public
    {
        alias Vector!(T, N) point_t;
        point_t a, b, c;

        static if (N == 2)
        {
            /// Returns: Area of a 2D triangle.
            @nogc T area() pure const nothrow
            {
                return abs(signedArea());
            }

            /// Returns: Signed area of a 2D triangle.
            @nogc T signedArea() pure const nothrow
            {
                return ((b.x * a.y - a.x * b.y)
                      + (c.x * b.y - b.x * c.y)
                      + (a.x * c.y - c.x * a.y)) / 2;
            }
        }

        static if (N == 3 && isFloatingPoint!T)
        {
            /// Returns: Triangle normal.
            @nogc Vector!(T, 3) computeNormal() pure const nothrow
            {
                return cross(b - a, c - a).normalized();
            }
        }
    }
}

alias Triangle!(float, 2) triangle2f;  /// 2D float triangle.
alias Triangle!(float, 3) triangle3f;  /// 3D float triangle.
alias Triangle!(double, 2) triangle2d; /// 2D double triangle.
alias Triangle!(double, 3) triangle3d; /// 3D double triangle.

/// A Sphere is a point + a radius.
struct Sphere(T, int N)
{
    public nothrow
    {
        alias Vector!(T, N) point_t;
        point_t center;
        T radius;

        /// Creates a sphere from a point and a radius.
        @nogc this(in point_t center_, T radius_) pure nothrow
        {
            center = center_;
            radius = radius_;
        }

        /// Sphere contains point test.
        /// Returns: true if the point is inside the sphere.
        @nogc bool contains(in Sphere s) pure const nothrow
        {
            if (s.radius > radius)
                return false;

            T innerRadius = radius - s.radius;
            return squaredDistanceTo(s.center) < innerRadius * innerRadius;
        }

        /// Sphere vs point Euclidean distance squared.
        @nogc T squaredDistanceTo(point_t p) pure const nothrow
        {
            return center.squaredDistanceTo(p);
        }

        /// Sphere vs sphere intersection.
        /// Returns: true if the spheres intersect.
        @nogc bool intersects(Sphere s) pure const nothrow
        {
            T outerRadius = radius + s.radius;
            return squaredDistanceTo(s.center) < outerRadius * outerRadius;
        }

        static if (isFloatingPoint!T)
        {
            /// Sphere vs point Euclidean distance.
            @nogc T distanceTo(point_t p) pure const nothrow
            {
                return center.distanceTo(p);
            }

            static if(N == 2)
            {
                /// Returns: Circle area.
                @nogc T area() pure const nothrow
                {
                    return T(PI) * (radius * radius);
                }
            }
        }
    }
}

alias Sphere!(float, 2) sphere2f;  /// 2D float sphere (ie. a circle).
alias Sphere!(float, 3) sphere3f;  /// 3D float sphere.
alias Sphere!(double, 2) sphere2d; /// 2D double sphere (ie. a circle).
alias Sphere!(double, 3) sphere3d; /// 3D double sphere (ie. a circle).


/// A Ray ir a point + a direction.
struct Ray(T, int N)
{
nothrow:
    public
    {
        alias Vector!(T, N) point_t;
        point_t orig;
        point_t dir;

        /// Returns: A point further along the ray direction.
        @nogc point_t progress(T t) pure const nothrow
        {
            return orig + dir * t;
        }

        static if (N == 3 && isFloatingPoint!T)
        {
            /// Ray vs triangle intersection.
            /// See_also: "Fast, Minimum Storage Ray/Triangle intersection", Mommer & Trumbore (1997)
            /// Returns: Barycentric coordinates, the intersection point is at $(D (1 - u - v) * A + u * B + v * C).
            @nogc bool intersect(Triangle!(T, 3) triangle, out T t, out T u, out T v) pure const nothrow
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

            /// Ray vs plane intersection.
            /// See_also: "Geometry for Computer Graphics: Formulae, Examples
            ///     and Proofs", Vince (2005), p. 62
            /// Returns: $(D true) if the ray crosses the plane exactly once,
            ///     or $(D false) if the ray is parallel to or points away from
            ///     the plane
            /// Params:
            ///     plane = Plane to intersect.
            ///     intersection = Point of intersection.
            ///     distance = set to the point's distance along the ray, or
            ///                T.infinity if parallel to the plane
            @nogc bool intersect(Plane!T plane, out point_t intersection, out T distance) pure const nothrow
            {
                // dot product will be 0 if angle to plane is 0
                T dp = dot(plane.n, dir);
                if (abs(dp) < T.epsilon)
                {
                    distance = T.infinity;
                    return false; // parallel to plane
                }

                // distance along ray where intersection happens
                distance = -(dot(plane.n, orig) - plane.d) / dp;

                intersection = distance*dir + orig;
                return distance >= 0;
            }
        }
    }
}

alias Ray!(float, 2) ray2f;  /// 2D float ray.
alias Ray!(float, 3) ray3f;  /// 3D float ray.
alias Ray!(double, 2) ray2d; /// 2D double ray.
alias Ray!(double, 3) ray3d; /// 3D double ray.


/// 3D plane.
/// See_also: Flipcode article by Nate Miller $(WEB www.flipcode.com/archives/Plane_Class.shtml).
struct Plane(T) if (isFloatingPoint!T)
{
    public
    {
        vec3!T n; /// Normal (always stored normalized).
        T d;

        /// Create from four coordinates.
        @nogc this(vec4!T abcd) pure nothrow
        {
            n = vec3!T(abcd.x, abcd.y, abcd.z).normalized();
            d = abcd.w;
        }

        /// Create from a point and a normal.
        @nogc this(vec3!T origin, vec3!T normal) pure nothrow
        {
            n = normal.normalized();
            d = -dot(origin, n);
        }

        /// Create from 3 non-aligned points.
        @nogc this(vec3!T A, vec3!T B, vec3!T C) pure nothrow
        {
            this(C, cross(B - A, C - A));
        }

        /// Assign a plane with another plane.
        @nogc ref Plane opAssign(Plane other) pure nothrow
        {
            n = other.n;
            d = other.d;
            return this;
        }

        /// Returns: signed distance between a point and the plane.
        @nogc T signedDistanceTo(vec3!T point) pure const nothrow
        {
            return dot(n, point) + d;
        }

        /// Returns: absolute distance between a point and the plane.
        @nogc T distanceTo(vec3!T point) pure const nothrow
        {
            return abs(signedDistanceTo(point));
        }

        /// Returns: true if the point is in front of the plane.
        @nogc bool isFront(vec3!T point) pure const nothrow
        {
            return signedDistanceTo(point) >= 0;
        }

        /// Returns: true if the point is in the back of the plane.
        @nogc bool isBack(vec3!T point) pure const nothrow
        {
            return signedDistanceTo(point) < 0;
        }

        /// Returns: true if the point is on the plane, with a given epsilon.
        @nogc bool isOn(vec3!T point, T epsilon) pure const nothrow
        {
            T sd = signedDistanceTo(point);
            return (-epsilon < sd) && (sd < epsilon);
        }
    }
}

alias Plane!float planef;  /// 3D float plane.
alias Plane!double planed; /// 3D double plane.

unittest
{
    auto p = planed(vec4d(1.0, 2.0, 3.0, 4.0));
    auto p2 = planed(vec3d(1.0, 0.0, 0.0),
                     vec3d(0.0, 1.0, 0.0),
                     vec3d(0.0, 0.0, 1.0));

    assert(p2.isOn(vec3d(1.0, 0.0, 0.0), 1e-7));
    assert(p2.isFront(vec3d(1.0, 1.0, 1.0)));
    assert(p2.isBack(vec3d(0.0, 0.0, 0.0)));
}

/// Plane intersection tests
@nogc pure nothrow unittest
{
    void testR(planed p, ray3d r, bool shouldIntersect, double expectedDistance, vec3d expectedPoint = vec3d.init) pure nothrow @nogc
    {
        vec3d point;
        double distance;
        assert(r.intersect(p, point, distance) == shouldIntersect);
        assert(approxEqual(distance, expectedDistance));
        if (shouldIntersect)
            assert(approxEqual(point.v[], expectedPoint.v[]));
    }
    // ray facing plane
    testR(planed(vec4d(1.0, 0.0, 0.0, 1.0)), ray3d(vec3d(2.0, 3.0, 4.0), vec3d(-1.0, 0.0, 0.0)),
        true, 1.0, vec3d(1.0, 3.0, 4.0));
    testR(planed(vec4d(1.0, 1.0, 1.0, -sqrt(3.0))), ray3d(vec3d(1.0, 1.0, 1.0), vec3d(-1.0, -1.0, -1.0).normalized()),
        true, 2.0*sqrt(3.0), vec3d(-1.0, -1.0, -1.0));
    // ray facing away
    testR(planed(vec4d(1.0, 0.0, 0.0, 1.0)), ray3d(vec3d(2.0, 3.0, 4.0), vec3d(1.0, 0.0, 0.0)),
        false, -1.0);
    testR(planed(vec4d(1.0, 0.0, 0.0, 5.0)), ray3d(vec3d(2.0, 3.0, 4.0), vec3d(-1.0, 0.0, 0.0)),
        false, -3.0);
    // ray parallel
    testR(planed(vec4d(0.0, 0.0, 1.0, 1.0)), ray3d(vec3d(1.0, 2.0, 3.0), vec3d(1.0, 0.0, 0.0)),
        false, double.infinity);

    void testS(planed p, seg3d s, bool shouldIntersect, double expectedProgress, vec3d expectedPoint = vec3d.init) pure nothrow @nogc
    {
        vec3d point;
        double progress;
        assert(s.intersect(p, point, progress) == shouldIntersect);
        assert(approxEqual(progress, expectedProgress));
        if (shouldIntersect)
            assert(approxEqual(point.v[], expectedPoint.v[]));
    }
    // segment crossing plane
    testS(planed(vec4d(1.0, 0.0, 0.0, 2.0)), seg3d(vec3d(1.0, 2.0, 3.0), vec3d(3.0, 4.0, 5.0)),
        true, 0.5, vec3d(2.0, 3.0, 4.0));
    // segment too short
    testS(planed(vec4d(1.0, 0.0, 0.0, 0.0)), seg3d(vec3d(1.0, 2.0, 3.0), vec3d(3.0, 4.0, 5.0)),
        false, -0.5);
}


/// 3D frustum.
/// See_also: Flipcode article by Dion Picco $(WEB www.flipcode.com/archives/Frustum_Culling.shtml).
/// Bugs: verify proper signedness of half-spaces
struct Frustum(T) if (isFloatingPoint!T)
{
    public
    {
        enum int LEFT   = 0,
                 RIGHT  = 1,
                 TOP    = 2,
                 BOTTOM = 3,
                 NEAR   = 4,
                 FAR    = 5;

        Plane!T[6] planes;

        /// Create a frustum from 6 planes.
        @nogc this(Plane!T left, Plane!T right, Plane!T top, Plane!T bottom, Plane!T near, Plane!T far) pure nothrow
        {
            planes[LEFT] = left;
            planes[RIGHT] = right;
            planes[TOP] = top;
            planes[BOTTOM] = bottom;
            planes[NEAR] = near;
            planes[FAR] = far;
        }

        enum : int
        {
            OUTSIDE,   /// object is outside the frustum
            INTERSECT, /// object intersects with the frustum
            INSIDE     /// object is inside the frustum
        }

        /// Point vs frustum intersection.
        @nogc bool contains(vec3!T point) pure const nothrow
        {
            for(int i = 0; i < 6; ++i)
            {
                T distance = planes[i].signedDistanceTo(point);

                if(distance < 0)
                    return false;
            }
            return true;
        }

        /// Sphere vs frustum intersection.
        /// Returns: Frustum.OUTSIDE, Frustum.INTERSECT or Frustum.INSIDE.
        @nogc int contains(Sphere!(T, 3) sphere) pure const nothrow
        {
            // calculate our distances to each of the planes
            for(int i = 0; i < 6; ++i)
            {
                // find the distance to this plane
                T distance = planes[i].signedDistanceTo(sphere.center);

                if(distance < -sphere.radius)
                    return OUTSIDE;

                else if (distance < sphere.radius)
                    return INTERSECT;
            }

            // otherwise we are fully in view
            return INSIDE;
        }

        /// AABB vs frustum intersection.
        /// Returns: Frustum.OUTSIDE, Frustum.INTERSECT or Frustum.INSIDE.
        @nogc int contains(box3!T box) pure const nothrow
        {
            vec3!T[8] corners;
            int totalIn = 0;

            for (int i = 0; i < 2; ++i)
                for (int j = 0; j < 2; ++j)
                    for (int k = 0; k < 2; ++k)
                    {
                        auto x = i == 0 ? box.min.x : box.max.x;
                        auto y = j == 0 ? box.min.y : box.max.y;
                        auto z = k == 0 ? box.min.z : box.max.z;
                        corners[i*4 + j*2 + k] = vec3!T(x, y, z);
                    }

            // test all 8 corners against the 6 sides
            // if all points are behind 1 specific plane, we are out
            // if we are in with all points, then we are fully in
            for(int p = 0; p < 6; ++p)
            {
                int inCount = 8;
                int ptIn = 1;

                for(int i = 0; i < 8; ++i)
                {
                    // test this point against the planes
                    if (planes[p].isBack(corners[i]))
                    {
                        ptIn = 0;
                        --inCount;
                    }
                }

                // were all the points outside of plane p?
                if (inCount == 0)
                    return OUTSIDE;

                // check if they were all on the right side of the plane
                totalIn += ptIn;
            }

            // so if totalIn is 6, then all are inside the view
            if(totalIn == 6)
                return INSIDE;

            // we must be partly in then otherwise
            return INTERSECT;
        }

    }
}

unittest
{
    seg2f se;
    triangle3f tr;
    Frustum!double frust;
    planed pl;
}

/// True if `T` is a kind of Segment
enum isSegment(T) = is(T : Segment!U, U...);

/// True if `T` is a kind of Triangle
enum isTriangle(T) = is(T : Triangle!U, U...);

/// True if `T` is a kind of Sphere
enum isSphere(T) = is(T : Sphere!U, U...);

/// True if `T` is a kind of Ray
enum isRay(T) = is(T : Ray!U, U...);

/// True if `T` is a kind of Plane
enum isPlane(T) = is(T : Plane!U, U);

/// True if `T` is a kind of Frustum
enum isFrustum(T) = is(T : Frustum!U, U);

/// True if `T` is a kind of 2 dimensional Segment
enum isSegment2D(T) = is(T : Segment!(U, 2), U);

/// True if `T` is a kind of 2 dimensional Triangle
enum isTriangle2D(T) = is(T : Triangle!(U, 2), U);

/// True if `T` is a kind of 2 dimensional Sphere
enum isSphere2D(T) = is(T : Sphere!(U, 2), U);

/// True if `T` is a kind of 2 dimensional Ray
enum isRay2D(T) = is(T : Ray!(U, 2), U);

/// True if `T` is a kind of 3 dimensional Segment
enum isSegment3D(T) = is(T : Segment!(U, 3), U);

/// True if `T` is a kind of 3 dimensional Triangle
enum isTriangle3D(T) = is(T : Triangle!(U, 3), U);

/// True if `T` is a kind of 3 dimensional Sphere
enum isSphere3D(T) = is(T : Sphere!(U, 3), U);

/// True if `T` is a kind of 3 dimensional Ray
enum isRay3D(T) = is(T : Ray!(U, 3), U);

unittest
{
    enum ShapeType
    {
        segment,
        triangle,
        sphere,
        ray,
        plane,
        frustum
    }

    void test(T, ShapeType type, int dim)()
    {
        with (ShapeType)
        {
            static assert(isSegment!T  == (type == segment ));
            static assert(isTriangle!T == (type == triangle));
            static assert(isSphere!T   == (type == sphere  ));
            static assert(isRay!T      == (type == ray     ));
            static assert(isPlane!T    == (type == plane   ));
            static assert(isFrustum!T  == (type == frustum ));

            static assert(isSegment2D!T  == (type == segment  && dim == 2));
            static assert(isTriangle2D!T == (type == triangle && dim == 2));
            static assert(isSphere2D!T   == (type == sphere   && dim == 2));
            static assert(isRay2D!T      == (type == ray      && dim == 2));

            static assert(isSegment3D!T  == (type == segment  && dim == 3));
            static assert(isTriangle3D!T == (type == triangle && dim == 3));
            static assert(isSphere3D!T   == (type == sphere   && dim == 3));
            static assert(isRay3D!T      == (type == ray      && dim == 3));
        }
    }

    with (ShapeType)
    {
        //    test case         type      #dimensions
        test!(seg2f           , segment , 2);
        test!(seg3d           , segment , 3);
        test!(triangle2d      , triangle, 2);
        test!(triangle3f      , triangle, 3);
        test!(sphere2d        , sphere  , 2);
        test!(Sphere!(uint, 3), sphere  , 3);
        test!(ray2f           , ray     , 2);
        test!(Ray!(real, 3)   , ray     , 3);
        test!(planed          , plane   , 0); // ignore dimension (always 3D)
        test!(Plane!float     , plane   , 0);
        test!(Frustum!double  , frustum , 0);
    }
}

/// Get the numeric type used to measure a shape's dimensions.
alias DimensionType(T : Segment!U, U...) = U[0];
/// ditto
alias DimensionType(T : Triangle!U, U...) = U[0];
/// ditto
alias DimensionType(T : Sphere!U, U...) = U[0];
/// ditto
alias DimensionType(T : Ray!U, U...) = U[0];
/// ditto
alias DimensionType(T : Plane!U, U) = U;
/// ditto
alias DimensionType(T : Frustum!U, U) = U;

///
unittest
{
    static assert(is(DimensionType!seg2i          == int));
    static assert(is(DimensionType!triangle3d     == double));
    static assert(is(DimensionType!sphere2d       == double));
    static assert(is(DimensionType!ray3f          == float));
    static assert(is(DimensionType!planed         == double));
    static assert(is(DimensionType!(Frustum!real) == real));
}
