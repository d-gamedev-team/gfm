/**
  Useful math functions and range-based statistic computations.

  If you need real statistics, consider using the $(WEB github.com/dsimcha/dstats,Dstats) library.
 */
module gfm.math.funcs;

import std.math,
       std.traits,
       std.range,
       std.math;

import gfm.math.vector : Vector;

version( D_InlineAsm_X86 )
{
    version = AsmX86;
}
else version( D_InlineAsm_X86_64 )
{
    version = AsmX86;
}

/// Convert from radians to degrees.
@nogc T degrees(T)(in T x) pure nothrow
if (isFloatingPoint!T || (is(T : Vector!(U, n), U, int n) && isFloatingPoint!U))
{
    static if (is(T : Vector!(U, n), U, int n))
        return x * U(180 / PI);
    else
        return x * T(180 / PI);
}

/// Convert from degrees to radians.
@nogc T radians(T)(in T x) pure nothrow
if (isFloatingPoint!T || (is(T : Vector!(U, n), U, int n) && isFloatingPoint!U))
{
    static if (is(T : Vector!(U, n), U, int n))
        return x * U(PI / 180);
    else
        return x * T(PI / 180);
}

/// Linear interpolation, akin to GLSL's mix.
@nogc S lerp(S, T)(S a, S b, T t) pure nothrow
  if (is(typeof(t * b + (1 - t) * a) : S))
{
    return t * b + (1 - t) * a;
}

/// Clamp x in [min, max], akin to GLSL's clamp.
@nogc T clamp(T)(T x, T min, T max) pure nothrow
{
    if (x < min)
        return min;
    else if (x > max)
        return max;
    else
        return x;
}

/// Integer truncation.
@nogc long ltrunc(real x) nothrow // may be pure but trunc isn't pure
{
    return cast(long)(trunc(x));
}

/// Integer flooring.
@nogc long lfloor(real x) nothrow // may be pure but floor isn't pure
{
    return cast(long)(floor(x));
}

/// Returns: Fractional part of x.
@nogc T fract(T)(real x) nothrow
{
    return x - lfloor(x);
}

/// Safe asin: input clamped to [-1, 1]
@nogc T safeAsin(T)(T x) pure nothrow
{
    return asin(clamp!T(x, -1, 1));
}

/// Safe acos: input clamped to [-1, 1]
@nogc T safeAcos(T)(T x) pure nothrow
{
    return acos(clamp!T(x, -1, 1));
}

/// Same as GLSL step function.
/// 0.0 is returned if x < edge, and 1.0 is returned otherwise.
@nogc T step(T)(T edge, T x) pure nothrow
{
    return (x < edge) ? 0 : 1;
}

/// Same as GLSL smoothstep function.
/// See: http://en.wikipedia.org/wiki/Smoothstep
@nogc T smoothStep(T)(T a, T b, T t) pure nothrow
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
@nogc bool isPowerOf2(T)(T i) pure nothrow if (isIntegral!T)
{
    assert(i >= 0);
    return (i != 0) && ((i & (i - 1)) == 0);
}

/// Integer log2
/// TODO: use bt intrinsics
@nogc int ilog2(T)(T i) nothrow if (isIntegral!T)
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
@nogc int nextPowerOf2(int i) pure nothrow
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
@nogc long nextPowerOf2(long i) pure nothrow
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
/// See_also: $(WEB www.plunk.org/~hatch/rightway.php)
@nogc T sinOverX(T)(T x) pure nothrow
{
    if (1 + x * x == 1)
        return 1;
    else
        return sin(x) / x;
}


/// Signed integer modulo a/b where the remainder is guaranteed to be in [0..b[,
/// even if a is negative. Only support positive dividers.
@nogc T moduloWrap(T)(T a, T b) pure nothrow if (isSigned!T)
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
@nogc int solveLinear(T)(T a, T b, out T root) pure nothrow if (isFloatingPoint!T)
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
 *     a = Coefficient.
 *     b = Coefficient.
 *     c = Coefficient.
 *     outRoots = array of root results, should have room for at least 2 elements.
 * Returns: Number of roots in outRoots.
 */
@nogc int solveQuadratic(T)(T a, T b, T c, T[] outRoots) pure nothrow if (isFloatingPoint!T)
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
 *     a = Coefficient.
 *     b = Coefficient.
 *     c = Coefficient.
 *     d = Coefficient.
 *     outRoots = array of root results, should have room for at least 2 elements.
 * Returns: Number of roots in outRoots.
 * See_also: $(WEB www.codeguru.com/forum/archive/index.php/t-265551.html)
 */
@nogc int solveCubic(T)(T a, T b, T c, T d, T[] outRoots) pure nothrow if (isFloatingPoint!T)
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
@nogc int solveQuartic(T)(T a, T b, T c, T d, T e, T[] roots) pure nothrow if (isFloatingPoint!T)
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
    int numRoots = solveCubic!T(b0, b1, b2, 1, resolventCubicRoots[]);
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
        int numRoots = solveCubic!double(-2, -3 / 2.0, 3 / 4.0, 1 / 4.0, roots[]);
        assert(numRoots == 3);
        assert(arrayContainsRoot(roots[], -4));
        assert(arrayContainsRoot(roots[], -1));
        assert(arrayContainsRoot(roots[], 2));
    }

    // test quartic
    {
        double[4] roots;
        int numRoots = solveQuartic!double(0, -2, -1, 2, 1, roots[]);

        assert(numRoots == 4);
        assert(arrayContainsRoot(roots[], -2));
        assert(arrayContainsRoot(roots[], -1));
        assert(arrayContainsRoot(roots[], 0));
        assert(arrayContainsRoot(roots[], 1));
    }
}

/// Arithmetic mean.
double average(R)(R r) if (isInputRange!R)
{
    if (r.empty)
        return double.nan;

    typeof(r.front()) sum = 0;
    long count = 0;
    foreach(e; r)
    {
        sum += e;
        ++count;
    }
    return sum / count;
}

/// Minimum of a range.
double minElement(R)(R r) if (isInputRange!R)
{
    // do like Javascript for an empty range
    if (r.empty)
        return double.infinity;

    return minmax!("<", R)(r);
}

/// Maximum of a range.
double maxElement(R)(R r) if (isInputRange!R)
{
    // do like Javascript for an empty range
    if (r.empty)
        return -double.infinity;

    return minmax!(">", R)(r);
}

/// Variance of a range.
double variance(R)(R r) if (isForwardRange!R)
{
    if (r.empty)
        return double.nan;

    auto avg = average(r.save); // getting the average

    typeof(avg) sum = 0;
    long count = 0;
    foreach(e; r)
    {
        sum += (e - avg) ^^ 2;
        ++count;
    }
    if (count <= 1)
        return 0.0;
    else
        return (sum / (count - 1.0)); // using sample std deviation as estimator
}

/// Standard deviation of a range.
double standardDeviation(R)(R r) if (isForwardRange!R)
{
    return sqrt(variance(r));
}

private
{
    typeof(R.front()) minmax(string op, R)(R r) if (isInputRange!R)
    {
        assert(!r.empty);
        auto best = r.front();
        r.popFront();
        foreach(e; r)
        {
            mixin("if (e " ~ op ~ " best) best = e;");
        }
        return best;
    }
}

/// SSE approximation of reciprocal square root.
@nogc T inverseSqrt(T)(T x) pure nothrow if (isFloatingPoint!T)
{
    version(AsmX86)
    {
        static if (is(T == float))
        {
            float result;

            asm pure nothrow @nogc 
            {
                movss XMM0, x; 
                rsqrtss XMM0, XMM0; 
                movss result, XMM0; 
            }
            return result;
        }
        else
            return 1 / sqrt(x);
    }
    else
        return 1 / sqrt(x);
}

unittest
{
    assert(abs( inverseSqrt!float(1) - 1) < 1e-3 );
    assert(abs( inverseSqrt!double(1) - 1) < 1e-3 );
}