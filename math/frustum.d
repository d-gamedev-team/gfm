module gfm.math.frustum;

import std.math,
       std.traits;

import gfm.math.vector,
       gfm.math.plane;

/**
 * 3D frustum.
 * From the flipcode article by Dion Picco.
 * http://www.flipcode.com/archives/Frustum_Culling.shtml
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
    }
}
