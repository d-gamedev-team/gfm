module gfm.math.frustum;

import std.math,
       std.traits;

import gfm.math.vector,
       gfm.math.plane,
       gfm.math.shapes,
       gfm.math.box;

/**
 * 3D frustum.
 * From the flipcode article by Dion Picco.
 * http://www.flipcode.com/archives/Frustum_Culling.shtml
 * TODO: verify proper signedness of half-spaces
 */
align(1) struct Frustum(T) if (isFloatingPoint!T)
{
    public
    {
        enum size_t LEFT = 0, 
                    RIGHT = 1,
                    TOP = 2,
                    BOTTOM = 3,
                    NEAR = 4,
                    FAR = 5;

        Plane!T[6] planes;

        /// create from 6 planes
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

        /// sphere-frustum intersection
        int contains(Sphere!(T, 3u) sphere) pure const nothrow
        {
            float fDistance;

            // calculate our distances to each of the planes
            for(size_t i = 0; i < 6; ++i) 
            {
                // find the distance to this plane
                float distance = planes[i].signedDistanceTo(sphere.center);

                if(distance < -sphere.radius)
                    return OUTSIDE;

                else if (distance < sphere.radius)
                    return INTERSECT;
            }

            // otherwise we are fully in view
            return INSIDE;
        }
    }
}
