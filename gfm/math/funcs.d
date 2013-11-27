module gfm.math.funcs;

import std.math,
       std.traits;

/// Returns: minimum of a and b.
T min(T)(T a, T b) pure nothrow
{
    return a < b ? a : b;
}

/// Returns: maximum of a and b.
T max(T)(T a, T b) pure nothrow
{
    return a > b ? a : b;
}

/// Convert from radians to degrees.
T degrees(T)(T x) pure if (!isIntegral!T)
{
    return x * (180 / PI);
}

/// Convert from degrees to radians.
T radians(T)(T x) pure nothrow if (!isIntegral!T)
{
    return x * (PI / 180);
}

/// Linear intepolation, akin to GLSL's mix.
S lerp(S, T)(S a, S b, T t) pure nothrow
{
    return t * b + (1 - t) * a;
}

/// old name of lerp was mix, but all in all it's a bad name
deprecated S mix(S, T)(S a, S b, T t) pure nothrow
{
    return t * b + (1 - t) * a;
}

/// Clamp x in [min, max], akin to GLSL's clamp.
T clamp(T)(T x, T min, T max) pure nothrow
{
    if (x < min)
        return min;
    else if (x > max)
        return max;
    else
        return x;
}

/// Integer truncation.
long ltrunc(real x) nothrow // may be pure but trunc isn't pure
{
    return cast(long)(trunc(x));
}

/// Integer flooring.
long lfloor(real x) nothrow // may be pure but floor isn't pure
{
    return cast(long)(floor(x));
}

/// Returns: Fractional part of x.
T fract(T)(real x) nothrow
{
    return x - lfloor(x);
}

/// Square
/// Deprecated: use the ^^ operator instead.
deprecated T square(T)(T s) pure nothrow
{
    return s * s;
}
deprecated alias square sqr;

/// Cube
/// Deprecated: use the ^^ operator instead.
deprecated T cube(T)(T s) pure nothrow
{
    return s * s * s;
}

/// Safe asin: input clamped to [-1, 1]
T safeAsin(T)(T x) pure nothrow
{
    return asin(clamp!T(x, -1, 1));
}

/// Safe acos: input clamped to [-1, 1]
T safeAcos(T)(T x) pure nothrow
{
    return acos(clamp!T(x, -1, 1));
}

/// Same as GLSL step function.
/// 0.0 is returned if x < edge, and 1.0 is returned otherwise.
T step(T)(T edge, T x) pure nothrow
{
    return (x < edge) ? 0 : 1;
}

/// Same as GLSL smoothstep function.
/// See: http://en.wikipedia.org/wiki/Smoothstep
T smoothStep(T)(T a, T b, T t) pure nothrow
{
    if (t <= a) 
        return 0;
    else if (t >= b) 
        return 1;
    else
    {
        T x = (t - a) / (b - a);
        return x * x * (3 - 2 * x);
    }
}

/// Fast conversion from [0 - 1] range to [0..255]
///  Credits: Sam Hocevar.
deprecated ubyte ubyteFromFloat(float x) nothrow
{
    union IntFloat32
    {
        float f;
        uint i;
    }
    IntFloat32 u = void;
    u.f = 32768.0f + x * (255.0f / 256.0f);
    return cast(ubyte)(u.i);
}

/// Returns: true of i is a power of 2.
bool isPowerOf2(T)(T i) nothrow if (isIntegral!T)
{
    assert(i >= 0);
    return (i != 0) && ((i & (i - 1)) == 0);
}

/// Integer log2
/// TODO: use bt intrinsics
int ilog2(T)(T i) nothrow if (isIntegral!T)
{
    assert(i > 0);
    assert(isPowerOf2(i));
    int result = 0;
    while (i > 1)
    {
        i = i / 2;
        result = result + 1;
    }
    return result;
}

/// Computes next power of 2.
int nextPowerOf2(int i) nothrow
{
    int v = i - 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v++;
    assert(isPowerOf2(v));
    return v;
}

/// Computes next power of 2.
long nextPowerOf2(long i) nothrow
{
    long v = i - 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v |= v >> 32;
    v++;
    assert(isPowerOf2(v));
    return v;
}

/// Computes sin(x)/x accurately.
/// See: http://www.plunk.org/~hatch/rightway.php
T sinOverX(T)(T x)
{
    if (1 + x * x == 1)
        return 1;
    else
        return sin(x) / x;
}


/// Signed integer modulo a/b where the remainder is guaranteed to be in [0..b[,
/// even if a is negative. Only support positive dividers.
T moduloWrap(T)(T a, T b) pure nothrow if (isSigned!T)
in
{
    assert(b > 0);
}
body
{
    if (a >= 0)
        a = a % b;
    else
    {
        auto rem = a % b;
        x = (rem == 0) ? 0 : (-rem + b);
    }

    assert(x >= 0 && x < b);
    return x;
}

unittest
{
    assert(nextPowerOf2(13) == 16);
}
