module gfm.math.plane;

import std.math,
       std.traits;

import gfm.math.vector;

/**
 * 3D plane
 * From the flipcode article by Nate Miller.
 * http://www.flipcode.com/archives/Plane_Class.shtml
 */
struct Plane(T) if (isFloatingPoint!T)
{
    public
    {
        vec3!T n; // normal (always normalized)
        T d;

        /// create from a point and a normal
        this(vec3!T origin, vec3!T normal)
        {
            n = normal.normalized;
            d = -dot(origin, n);
        }

        /// create from 3 non-aligned points
        this(vec3!T A, vec3!T B, vec3!T C)
        {
            this(cross(B - A, C - A), C);
        }

        /// signed distance
        T signedDistanceTo(vec3!T point) pure const nothrow
        {
            return dot(n, point) + d;
        }

        T distanceTo(vec3!T point) pure const nothrow
        {
            return abs(signedDistanceTo(point));
        }

        /// return true if the point is in front of the plane
        bool isFront(vec3!T point) pure const nothrow
        {
            return signedDistanceTo(point) >= 0;
        }

        /// return true if the point is in front of the plane
        bool isBack(vec3!T point) pure const nothrow
        {
            return signedDistanceTo(point) < 0;
        }

        /// return true if the point is on the plane, with a given epsilon
        bool isOn(vec3!T point, T epsilon) pure const nothrow
        {
            T sd = signedDistanceTo(point);
            return (-epsilon < d && d < epsilon);
        }
    }
}

unittest
{
    Plane3d

}