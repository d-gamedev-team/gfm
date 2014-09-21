module gfm.math.funcs;

import std.math,
       std.traits;

/// Returns: minimum of a and b.
T min(T)(T a, T b) pure nothrow @nogc
{
    return a < b ? a : b;
}

/// Returns: maximum of a and b.
T max(T)(T a, T b) pure nothrow @nogc
{
    return a > b ? a : b;
}

/// Convert from radians to degrees.
T degrees(T)(T x) pure nothrow @nogc if (!isIntegral!T)
{
    return x * (180 / PI);
}

/// Convert from degrees to radians.
T radians(T)(T x) pure nothrow @nogc if (!isIntegral!T)
{
    return x * (PI / 180);
}

/// Linear interpolation, akin to GLSL's mix.
S lerp(S, T)(S a, S b, T t) pure nothrow @nogc
{
    return t * b + (1 - t) * a;
}

/// Clamp x in [min, max], akin to GLSL's clamp.
T clamp(T)(T x, T min, T max) pure nothrow @nogc
{
    if (x < min)
        return min;
    else if (x > max)
        return max;
    else
        return x;
}

/// Integer truncation.
long ltrunc(real x) nothrow @nogc // may be pure but trunc isn't pure
{
    return cast(long)(trunc(x));
}

/// Integer flooring.
long lfloor(real x) nothrow @nogc // may be pure but floor isn't pure
{
    return cast(long)(floor(x));
}

/// Returns: Fractional part of x.
T fract(T)(real x) nothrow @nogc
{
    return x - lfloor(x);
}

/// Safe asin: input clamped to [-1, 1]
T safeAsin(T)(T x) pure nothrow @nogc
{
    return asin(clamp!T(x, -1, 1));
}

/// Safe acos: input clamped to [-1, 1]
T safeAcos(T)(T x) pure nothrow @nogc
{
    return acos(clamp!T(x, -1, 1));
}

/// Same as GLSL step function.
/// 0.0 is returned if x < edge, and 1.0 is returned otherwise.
T step(T)(T edge, T x) pure nothrow @nogc
{
    return (x < edge) ? 0 : 1;
}

/// Same as GLSL smoothstep function.
/// See: http://en.wikipedia.org/wiki/Smoothstep
T smoothStep(T)(T a, T b, T t) pure nothrow @nogc
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

/// Returns: true of i is a power of 2.
bool isPowerOf2(T)(T i) pure nothrow @nogc if (isIntegral!T)
{
    assert(i >= 0);
    return (i != 0) && ((i & (i - 1)) == 0);
}

/// Integer log2
/// TODO: use bt intrinsics
int ilog2(T)(T i) nothrow @nogc if (isIntegral!T)
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
int nextPowerOf2(int i) pure nothrow @nogc
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
long nextPowerOf2(long i) pure nothrow @nogc
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
T sinOverX(T)(T x) pure nothrow @nogc
{
    if (1 + x * x == 1)
        return 1;
    else
        return sin(x) / x;
}


/// Signed integer modulo a/b where the remainder is guaranteed to be in [0..b[,
/// even if a is negative. Only support positive dividers.
T moduloWrap(T)(T a, T b) pure nothrow @nogc if (isSigned!T)
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

/**
 * Find the root of a linear polynomial a + b x = 0
 * Returns: Number of roots.
 */
size_t solveLinear(T)(T a, T b, out T root) pure nothrow @nogc if (isFloatingPoint!T)
{
    if (b == 0)
    {
        return 0;
    }
    else
    {
        root = -a / b;
        return 1;
    }
}


/**
 * Finds the root roots of a quadratic polynomial a + b x + c x^2 = 0
 * Params:
 *     outRoots = array of root results, should have room for at least 2 elements.
 * Returns: Number of roots in outRoots.
 */
size_t solveQuadratic(T)(T a, T b, T c, T[] outRoots) pure nothrow @nogc if (isFloatingPoint!T)
{
    assert(outRoots.length >= 2);
    if (c == 0)
        return solveLinear(a, b, outRoots[0]);

    T delta = b * b - 4 * a * c;
    if (delta < 0.0 )
        return 0;

    delta = sqrt(delta);
    T oneOver2a = 0.5 / a;

    outRoots[0] = oneOver2a * (-b - delta);
    outRoots[1] = oneOver2a * (-b + delta);
    return 2;
}


/**
 * Finds the roots of a cubic polynomial  a + b x + c x^2 + d x^3 = 0
 * Params:
 *     outRoots = array of root results, should have room for at least 2 elements.
 * Returns: Number of roots in outRoots.
 * See_also: $(WEB www.codeguru.com/forum/archive/index.php/t-265551.html)
 */
size_t solveCubic(T)(T a, T b, T c, T d, T[] outRoots) pure nothrow @nogc if (isFloatingPoint!T)
{
    assert(outRoots.length >= 3);
    if (d == 0)
        return solveQuadratic(a, b, c, outRoots);

    // adjust coefficients
    T a1 = c / d,
      a2 = b / d,
      a3 = a / d;

    T Q = (a1 * a1 - 3 * a2) / 9,
      R = (2 * a1 * a1 * a1 - 9 * a1 * a2 + 27 * a3) / 54;

    T Qcubed = Q * Q * Q;
    T d2 = Qcubed - R * R;

    if (d2 >= 0)
    {
        // 3 real roots
        if (Q < 0.0)
            return 0;
        T P = R / sqrt(Qcubed);

        assert(-1 <= P && P <= 1);
        T theta = acos(P);
        T sqrtQ = sqrt(Q);

        outRoots[0] = -2 * sqrtQ * cos(theta / 3) - a1 / 3;
        outRoots[1] = -2 * sqrtQ * cos((theta + 2 * PI) / 3) - a1 / 3;
        outRoots[2] = -2 * sqrtQ * cos((theta + 4 * PI) / 3) - a1 / 3;
        return 3;
    }
    else
    {
        // 1 real root
        T e = (sqrt(-d) + abs(R)) ^^ cast(T)(1.0 / 3.0);
        if (R > 0)
            e = -e;
        outRoots[0] = e + Q / e - a1 / 3.0;
        return 1;
    }
}

/**
 * Returns the roots of a quartic polynomial  a + b x + c x^2 + d x^3 + e x^4 = 0
 *
 * Returns number of roots. roots slice should have room for up to 4 elements.
 * Bugs: doesn't pass unit-test!
 * See_also: $(WEB mathworld.wolfram.com/QuarticEquation.html)
 */
size_t solveQuartic(T)(T a, T b, T c, T d, T e, T[] roots) pure nothrow @nogc if (isFloatingPoint!T)
{
    assert(roots.length >= 4);

    if (e == 0)
        return solveCubic(a, b, c, d, roots);

    // Adjust coefficients
    T a0 = a / e,
      a1 = b / e,
      a2 = c / e,
      a3 = d / e;

    // Find a root for the following cubic equation:
    //     y^3 - a2 y^2 + (a1 a3 - 4 a0) y + (4 a2 a0 - a1 ^2 - a3^2 a0) = 0
    // aka Resolvent cubic
    T b0 = 4 * a2 * a0 - a1 * a1 - a3 * a3 * a0;
    T b1 = a1 * a3 - 4 * a0;
    T b2 = -a2;
    T[3] resolventCubicRoots;
    size_t numRoots = solveCubic!T(b0, b1, b2, 1, resolventCubicRoots[]);
    assert(numRoots == 3);
    T y = resolventCubicRoots[0];
    if (y < resolventCubicRoots[1]) y = resolventCubicRoots[1];
    if (y < resolventCubicRoots[2]) y = resolventCubicRoots[2];

    // Compute R, D & E
    T R = 0.25f * a3 * a3 - a2 + y;
    if (R < 0.0)
        return 0;
    R = sqrt(R);

    T D = void,
      E = void;
    if (R == 0)
    {
        T d1 = 0.75f * a3 * a3 - 2 * a2;
        T d2 = 2 * sqrt(y * y - 4 * a0);
        D = sqrt(d1 + d2) * 0.5f;
        E = sqrt(d1 - d2) * 0.5f;
    }
    else
    {
        T Rsquare = R * R;
        T Rrec = 1 / R;
        T d1 =  0.75f * a3 * a3 - Rsquare - 2 * a2;
        T d2 = 0.25f * Rrec * (4 * a3 * a2 - 8 * a1 - a3 * a3 * a3);
        D = sqrt(d1 + d2) * 0.5f;
        E = sqrt(d1 - d2) * 0.5f;
    }

    // Compute the 4 roots
    a3 *= -0.25f;
    R *= 0.5f;

    roots[0] = a3 + R + D;
    roots[1] = a3 + R - D;
    roots[2] = a3 - R + E;
    roots[3] = a3 - R - E;
    return 4;
}


unittest
{
    bool arrayContainsRoot(double[] arr, double root)
    {
        foreach(e; arr)
            if (abs(e - root) < 1e-7)
                return true;
        return false;
    }

    // test quadratic
    {
        double[3] roots;
        size_t numRoots = solveCubic!double(-2, -3 / 2.0, 3 / 4.0, 1 / 4.0, roots[]);
        assert(numRoots == 3);
        assert(arrayContainsRoot(roots[], -4));
        assert(arrayContainsRoot(roots[], -1));
        assert(arrayContainsRoot(roots[], 2));
    }

    // test quartic
    {
        double[4] roots;
        size_t numRoots = solveQuartic!double(0, -2, -1, 2, 1, roots[]);

        assert(numRoots == 4);
        assert(arrayContainsRoot(roots[], -2));
        assert(arrayContainsRoot(roots[], -1));
        assert(arrayContainsRoot(roots[], 0));
        assert(arrayContainsRoot(roots[], 1));
    }
}
