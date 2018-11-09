///
module gfm.math.quaternion;

import std.math,
       std.string;

import gfm.math.vector,
       gfm.math.matrix,
       funcs = gfm.math.funcs;

/// Quaternion implementation.
/// Holds a rotation + angle in a proper but wild space.
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

        /// Construct a Quaternion from a value.
        @nogc this(U)(U x) pure nothrow if (isAssignable!U)
        {
            opAssign!U(x);
        }

        /// Constructs a Quaternion from coordinates.
        /// Warning: order of coordinates is different from storage.
        @nogc this(T qw, T qx, T qy, T qz) pure nothrow
        {
            x = qx;
            y = qy;
            z = qz;
            w = qw;
        }

        /// Constructs a Quaternion from axis + angle.
        @nogc static Quaternion fromAxis(Vector!(T, 3) axis, T angle) pure nothrow
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

        /// Constructs a Quaternion from Euler angles.
        /// All paramers given in radians.
        /// Roll->X axis, Pitch->Y axis, Yaw->Z axis
        /// See_also: $(LINK https://www.cs.princeton.edu/~gewang/projects/darth/stuff/quat_faq.html)
        @nogc static Quaternion fromEulerAngles(T roll, T pitch, T yaw) pure nothrow
        {
            Quaternion q = void;
            T sinPitch = sin(pitch / 2);
            T cosPitch = cos(pitch / 2);
            T sinYaw = sin(yaw / 2);
            T cosYaw = cos(yaw / 2);
            T sinRoll = sin(roll / 2);
            T cosRoll = cos(roll / 2);
            T cosPitchCosYaw = cosPitch * cosYaw;
            T sinPitchSinYaw = sinPitch * sinYaw;
            q.x = sinRoll * cosPitchCosYaw    - cosRoll * sinPitchSinYaw;
            q.y = cosRoll * sinPitch * cosYaw + sinRoll * cosPitch * sinYaw;
            q.z = cosRoll * cosPitch * sinYaw - sinRoll * sinPitch * cosYaw;
            q.w = cosRoll * cosPitchCosYaw    + sinRoll * sinPitchSinYaw;
            return q;
        }

        /// Converts a quaternion to Euler angles.
        /// TODO: adds a EulerAngles type.
        /// Returns: A vector which contains roll-pitch-yaw as x-y-z.
        @nogc vec3!T toEulerAngles() pure const nothrow
        {
            mat3!T m = cast(mat3!T)(this);

            T pitch, yaw, roll;
            T s = sqrt(m.c[0][0] * m.c[0][0] + m.c[1][0] * m.c[1][0]);
            if (s > T.epsilon)
            {
                pitch = - atan2(m.c[2][0], s);
                yaw = atan2(m.c[1][0], m.c[0][0]);
                roll = atan2(m.c[2][1], m.c[2][2]);
            }
            else
            {
                pitch = m.c[2][0] < 0.0f ? T(PI) /2 : -T(PI) / 2;
                yaw = -atan2(m.c[0][1], m.c[1][1]);
                roll = 0.0f;
            }
            return vec3!T(roll, pitch, yaw);
        }

        /// Assign from another Quaternion.
        @nogc ref Quaternion opAssign(U)(U u) pure nothrow if (isQuaternionInstantiation!U && is(U._T : T))
        {
            v = u.v;
            return this;
        }

        /// Assign from a vector of 4 elements.
        @nogc ref Quaternion opAssign(U)(U u) pure nothrow if (is(U : Vector!(T, 4u)))
        {
            v = u;
            return this;
        }

        /// Converts to a pretty string.
        string toString() const nothrow
        {
            try
                return format("%s", v);
            catch (Exception e)
                assert(false); // should not happen since format is right
        }

        /// Normalizes a quaternion.
        @nogc void normalize() pure nothrow
        {
            v.normalize();
        }

        /// Returns: Normalized quaternion.
        @nogc Quaternion normalized() pure const nothrow
        {
            Quaternion res = void;
            res.v = v.normalized();
            return res;
        }

        /// Inverses a quaternion in-place.
        @nogc void inverse() pure nothrow
        {
            x = -x;
            y = -y;
            z = -z;
        }

        /// Returns: Inverse of quaternion.
        @nogc Quaternion inversed() pure const nothrow
        {
            Quaternion res = void;
            res.v = v;
            res.inverse();
            return res;
        }

        @nogc ref Quaternion opOpAssign(string op, U)(U q) pure nothrow
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

        @nogc ref Quaternion opOpAssign(string op, U)(U operand) pure nothrow if (isConvertible!U)
        {
            Quaternion conv = operand;
            return opOpAssign!op(conv);
        }

        @nogc Quaternion opBinary(string op, U)(U operand) pure const nothrow
            if (is(U: Quaternion) || (isConvertible!U))
        {
            Quaternion temp = this;
            return temp.opOpAssign!op(operand);
        }

        /// Compare two Quaternions.
        bool opEquals(U)(U other) pure const if (is(U : Quaternion))
        {
            return v == other.v;
        }

        /// Compare Quaternion and other types.
        bool opEquals(U)(U other) pure const nothrow if (isConvertible!U)
        {
            Quaternion conv = other;
            return opEquals(conv);
        }

        /// Convert to a 3x3 rotation matrix.
        /// TODO: check out why we can't do is(Unqual!U == mat3!T)
        @nogc U opCast(U)() pure const nothrow if (isMatrixInstantiation!U
                                                   && is(U._T : _T)
                                                   && (U._R == 3) && (U._C == 3))
        {
            // do not assume that quaternion is normalized
            T norm = x*x + y*y + z*z + w*w;
            T s = (norm > 0) ? 2 / norm : 0;

            T xx = x * x * s, xy = x * y * s, xz = x * z * s, xw = x * w * s,
                              yy = y * y * s, yz = y * z * s, yw = y * w * s,
                                              zz = z * z * s, zw = z * w * s;
            return mat3!(U._T)
            (
                1 - (yy + zz)   ,   (xy - zw)    ,   (xz + yw)    ,
                  (xy + zw)     , 1 - (xx + zz)  ,   (yz - xw)    ,
                  (xz - yw)     ,   (yz + xw)    , 1 - (xx + yy)
            );
        }

        /// Converts a to a 4x4 rotation matrix.
        /// Bugs: check why we can't do is(Unqual!U == mat4!T)
        @nogc U opCast(U)() pure const nothrow if (isMatrixInstantiation!U
                                                   && is(U._T : _T)
                                                   && (U._R == 4) && (U._C == 4))
        {
            auto m3 = cast(mat3!(U._T))(this);
            return cast(U)(m3);
        }

        /// Workaround Vector not being constructable through CTFE
        @nogc static Quaternion identity() pure nothrow @property
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

template isQuaternionInstantiation(U)
{
    private static void isQuaternion(T)(Quaternion!T x)
    {
    }

    enum bool isQuaternionInstantiation = is(typeof(isQuaternion(U.init)));
}

alias Quaternion!float quatf;///
alias Quaternion!double quatd;///

/// Linear interpolation, for quaternions.
@nogc Quaternion!T lerp(T)(Quaternion!T a, Quaternion!T b, float t) pure nothrow
{
    Quaternion!T res = void;
    res.v = funcs.lerp(a.v, b.v, t);
    return res;
}

/// Nlerp of quaternions
/// Returns: Nlerp of quaternions.
/// See_also: $(WEB keithmaggio.wordpress.com/2011/02/15/math-magician-lerp-slerp-and-nlerp/, Math Magician – Lerp, Slerp, and Nlerp)
@nogc Quaternion!T Nlerp(T)(Quaternion!T a, Quaternion!T b, float t) pure nothrow
{
    assert(t >= 0 && t <= 1); // else probably doesn't make sense
    Quaternion!T res = void;
    res.v = funcs.lerp(a.v, b.v, t);
    res.v.normalize();
    return res;
}

/// Slerp of quaternions
/// Returns: Slerp of quaternions. Slerp is more expensive than Nlerp.
/// See_also: "Understanding Slerp, Then Not Using It"
@nogc Quaternion!T slerp(T)(Quaternion!T a, Quaternion!T b, T t) pure nothrow
{
    assert(t >= 0 && t <= 1); // else probably doesn't make sense

    Quaternion!T res = void;

    T dotProduct = dot(a.v, b.v);

    // spherical lerp always has 2 potential paths
    // here we always take the shortest
    if (dotProduct < 0)
    {
        b.v *= -1;
        dotProduct = dot(a.v, b.v);
    }

    immutable T threshold = 10 * T.epsilon; // idMath uses 1e-6f for 32-bits float precision
    if ((1 - dotProduct) > threshold) // if small difference, use lerp
        return lerp(a, b, t);

    T theta_0 = funcs.safeAcos(dotProduct); // angle between this and other
    T theta = theta_0 * t; // angle between this and result

    vec3!T v2 = dot(b.v, a.v * dotProduct);
    v2.normalize();

    res.v = dot(b.v, a.v * dotProduct);
    res.v.normalize();

    res.v = a.v * cos(theta) + res.v * sin(theta);
    return res;
}

unittest
{
    quatf a = quatf.fromAxis(vec3f(1, 0, 0), 1);
    quatf b = quatf.fromAxis(vec3f(0, 1, 0), 0);
    a = a * b;

    quatf c = lerp(a, b, 0.5f);
    quatf d = Nlerp(a, b, 0.1f);
    quatf e = slerp(a, b, 0.0f);
    quatd f = quatd(1.0, 4, 5.0, 6.0);
    quatf g = quatf.fromEulerAngles(-0.1f, 1.2f, -0.3f);
    vec3f ga = g.toEulerAngles();
}
