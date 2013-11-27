module gfm.math.frustum;

import std.math,
       std.traits;

import gfm.math.vector,
       gfm.math.plane,
       gfm.math.shapes,
       gfm.math.box;

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
