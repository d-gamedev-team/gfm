module gfm.math.quaternion;

import std.math;
import gfm.math.vector;
import gfm.math.matrix;

// hold a rotation + angle in a proper but wild space
struct Quaternion(T)
{
    public
    {
        union
        {
            Vector!(T, 4u) v;
            struct
            {
                T x, y, z, w;
            }
        }

        // construct with value
        this(U)(U x) pure nothrow if (isAssignable!U)
        {
            opAssign!U(x);
        }

        // constructs from axis + angle
        static Quaternion fromAxis(Vector!(T, 3u) axis, T angle) pure nothrow
        {
            Quaternion q = void;
            axis.normalize();
            T cos_a = cos(angle / 2);
            T sin_a = sin(angle / 2);
            q.x = sin_a * axis.x;
            q.y = sin_a * axis.y;
            q.z = sin_a * axis.z;
            q.w = cos_a;
            return q; // should be normalized
        }

        // compatible Quaternions
        void opAssign(U)(U u) pure nothrow if (is(typeof(U._isQuaternion)) && is(U._T : T))
        {
            v = u.v;
        }

        // from a vector containing components
        void opAssign(U)(U u) pure nothrow if (is(U : Vector!(T, 4u)))
        {
            v = u;
        }

        // normalize quaternion
        void normalize() pure nothrow
        {
            v.normalize();
        }

        // return result of normalization
        Quaternion normalized() pure const nothrow
        {
            Quaternion res = void;
            res.v = v.normalized();
            return res;
        }

        Quaternion opOpAssign(string op, U)(U q) pure nothrow
            if (is(U : Quaternion) && (op == "*"))
        {
            T nx = w * q.x + x * q.w + y * q.z - z * q.y,
              ny = w * q.y + y * q.w + z * q.x - x * q.z,
              nz = w * q.z + z * q.w + x * q.y - y * q.x,
              nw = w * q.w - x * q.x - y * q.y - z * q.z;
            x = nx;
            y = ny;
            z = nz;
            w = nw;
            return this;
        }

        Quaternion opOpAssign(string op, U)(U operand) pure nothrow if (isConvertible!U)
        {
            Quaternion conv = operand;
            return opOpAssign!op(conv);
        }

        Quaternion opBinary(string op, U)(U operand) pure const nothrow 
            if (is(U: Quaternion) || (isConvertible!U))
        {
            Quaternion temp = this;
            return temp.opOpAssign!op(operand);
        }

        // compare two Quaternions
        bool opEquals(U)(U other) pure const if (is(U : Quaternion))
        {
            return v == other.v;
        }

        // compare Quaternion and other types
        bool opEquals(U)(U other) pure const nothrow if (isConvertible!U)
        {
            Quaternion conv = other;
            return opEquals(conv);
        }

        // convert to 3x3 rotation matrix
        U opCast(U)() pure const nothrow if (is(Unqual!U == mat3!T))
        {
            T xx = x * x, xy = x * y, xz = x * z, xw = x * w,
                          yy = y * y, yz = y * z, yw = y * w,
                                      zz = z * z, zw = z * w;
            return mat3!(T)
            (
                1 - 2 * (yy + zz)    , 2 * (xy - zw)        , 2 * (xz + yw)    ,
                2 * (xy + zw)        , 1 - 2 * (xx + zz)    , 2 * (yz - xw)    ,
                2 * (xz - yw)        , 2 * (yz + xw)        , 1 - 2 * (xx + yy)
            );
        }

        // convert to 4x4 rotation matrix
        U opCast(U)() pure const nothrow if (is(Unqual!U == mat4!T))
        {
            return cast(mat4!T)(cast(mat3!T)(this));
        }

        // Workaround Vector not being constructable through CTFE
        static Quaternion IDENTITY() pure nothrow @property
        {
            Quaternion q;
            q.x = q.y = q.z = 0;
            q.w = 1;
            return q;
        }
    }

    private
    {
        alias T _T;
        enum _isQuaternion = true;

        template isAssignable(T)
        {
            enum bool isAssignable =
                is(typeof(
                {
                    T x;
                    Quaternion v = x;
                }()));
        }

        // define types that can be converted to Quaternion, but are not Quaternion
        template isConvertible(T)
        {
            enum bool isConvertible = (!is(T : Quaternion)) && isAssignable!T;
        }
    }
}

alias Quaternion!float quaternionf;
alias Quaternion!double quaterniond;

unittest
{
    quaternionf a = quaternionf.fromAxis(vec3f(1, 0, 0), 1);
    quaternionf b = quaternionf.fromAxis(vec3f(0, 1, 0), 0);

    a = a * b;
}
