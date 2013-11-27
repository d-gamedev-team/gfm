module gfm.math.frustum;

import std.math,
       std.traits;

import gfm.math.vector,
       gfm.math.shapes,
       gfm.math.box;



/// 3D plane.
/// From the flipcode article by Nate Miller.
/// See: http://www.flipcode.com/archives/Plane_Class.shtml
align(1) struct Plane(T) if (isFloatingPoint!T)
{
    public
    {
        vec3!T n; // normal (always normalized)
        T d;

        /// Create from four coordinates.
        this(vec4!T abcd) pure nothrow
        {
            n = vec3!T(abcd.x, abcd.y, abcd.z).normalized();
            d = abcd.z;
        }

        /// Create from a point and a normal.
        this(vec3!T origin, vec3!T normal) pure nothrow
        {
            n = normal.normalized();
            d = -dot(origin, n);
        }

        /// Create from 3 non-aligned points.
        this(vec3!T A, vec3!T B, vec3!T C) pure nothrow
        {
            this(C, cross(B - A, C - A));
        }

        ref Plane opAssign(Plane other) pure nothrow
        {
            n = other.n;
            d = other.d;
            return this;
        }

        /// Returns: signed distance between a point and the plane.
        T signedDistanceTo(vec3!T point) pure const nothrow
        {
            return dot(n, point) + d;
        }

        /// Returns: absolute distance between a point and the plane.
        T distanceTo(vec3!T point) pure const nothrow
        {
            return abs(signedDistanceTo(point));
        }

        /// Returns: true if the point is in front of the plane.
        bool isFront(vec3!T point) pure const nothrow
        {
            return signedDistanceTo(point) >= 0;
        }

        /// Returns: true if the point is in the back of the plane.
        bool isBack(vec3!T point) pure const nothrow
        {
            return signedDistanceTo(point) < 0;
        }

        /// Returns: true if the point is on the plane, with a given epsilon.
        bool isOn(vec3!T point, T epsilon) pure const nothrow
        {
            T sd = signedDistanceTo(point);
            return (-epsilon < sd) && (sd < epsilon);
        }
    }
}

alias Plane!float planef;
alias Plane!double planed;

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



/// 3D frustum.
/// Implemented from the flipcode article by Dion Picco.
/// http://www.flipcode.com/archives/Frustum_Culling.shtml
/// TODO: verify proper signedness of half-spaces
align(1) struct Frustum(T) if (isFloatingPoint!T)
{
    public
    {
        enum size_t LEFT   = 0, 
                    RIGHT  = 1,
                    TOP    = 2,
                    BOTTOM = 3,
                    NEAR   = 4,
                    FAR    = 5;

        Plane!T[6] planes;

        /// Create a frustum from 6 planes.
        this(Plane!T left, Plane!T right, Plane!T top, Plane!T bottom, Plane!T near, Plane!T far) pure nothrow
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
        bool contains(vec3!T point) pure const nothrow
        {
            for(size_t i = 0; i < 6; ++i) 
            {
                T distance = planes[i].signedDistanceTo(point);

                if(distance < 0)
                    return false;
            }
            return true;
        }

        /// Sphere vs frustum intersection.
        /// Returns: Frustum.OUTSIDE, Frustum.INTERSECT or Frustum.INSIDE.
        int contains(Sphere!(T, 3u) sphere) pure const nothrow
        {
            // calculate our distances to each of the planes
            for(size_t i = 0; i < 6; ++i) 
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
        int contains(box3!T box) pure const nothrow
        {
            vec3!T corners[8];
            size_t totalIn = 0;

            for (size_t i = 0; i < 2; ++i)
                for (size_t j = 0; j < 2; ++j)
                    for (size_t k = 0; k < 2; ++j)
                    {
                        auto x = i == 0 ? box.min.x : box.max.x;
                        auto y = i == 0 ? box.min.y : box.max.y;
                        auto z = i == 0 ? box.min.z : box.max.z;
                        corners[i*4 + j*2 + k] = vec3!T(x, y, z);
                    }

            // test all 8 corners against the 6 sides
            // if all points are behind 1 specific plane, we are out
            // if we are in with all points, then we are fully in
            for(size_t p = 0; p < 6; ++p)
            {
                size_t inCount = 8;
                size_t ptIn = 1;

                for(size_t i = 0; i < 8; ++i)
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
