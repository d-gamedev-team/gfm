module gfm.math.plane;

import std.math,
       std.traits;

import gfm.math.vector;

/**
 * 3D plane
 * From the flipcode article by Nate Miller.
 * http://www.flipcode.com/archives/Plane_Class.shtml
 */
align(1) struct Plane(T) if (isFloatingPoint!T)
{
    public
    {
        vec3!T n; // normal (always normalized)
        T d;

        /// create from four coordinates
        this(vec4!T abcd) pure nothrow
        {
            n = vec3!T(abcd.x, abcd.y, abcd.z).normalized();
            d = abcd.z;
        }

        /// create from a point and a normal
        this(vec3!T origin, vec3!T normal) pure nothrow
        {
            n = normal.normalized();
            d = -dot(origin, n);
        }

        /// create from 3 non-aligned points
        this(vec3!T A, vec3!T B, vec3!T C) pure nothrow
        {
            this(C, cross(B - A, C - A));
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